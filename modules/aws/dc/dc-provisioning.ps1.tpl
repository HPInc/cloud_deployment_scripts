# Copyright Teradici Corporation 2020-2021;  © Copyright 2022-2023 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

##### Template Variables #####
$ADMIN_PASSWORD              = "${admin_password}"
$AWS_SSM_ENABLE              = "${aws_ssm_enable}"
$BASE_DIR                    = "C:\Teradici"
$BUCKET_NAME                 = "${bucket_name}"
$CLOUDWATCH_ENABLE           = "${cloudwatch_enable}"
$CLOUDWATCH_SETUP_SCRIPT     = "${cloudwatch_setup_script}"
$DC_NEW_AD_ACCOUNTS_SCRIPT   = "${dc_new_ad_accounts_script}"
$DOMAIN_NAME                 = "${domain_name}"
$LDAPS_CERT_FILENAME         = "${ldaps_cert_filename}"
$TAG_NAME                    = "${tag_name}"
$PCOIP_AGENT_INSTALL         = "${pcoip_agent_install}"
$PCOIP_AGENT_VERSION         = "${pcoip_agent_version}"
$PCOIP_REGISTRATION_CODE     = "${pcoip_registration_code}"
$SAFE_MODE_ADMIN_PASSWORD    = "${safe_mode_admin_password}"
$TERADICI_DOWNLOAD_TOKEN     = "${teradici_download_token}"

$LOG_FILE = "$BASE_DIR\provisioning.log"

$AWS_SSM_URL       = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
$AWS_SSM_INSTALLER = Split-Path $AWS_SSM_URL -leaf

$PCOIP_AGENT_LOCATION_URL = "https://dl.teradici.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/raw/names/pcoip-agent-standard-exe/versions/$PCOIP_AGENT_VERSION"
$PCOIP_AGENT_FILENAME     = "pcoip-agent-standard_$PCOIP_AGENT_VERSION.exe"

$INSTANCEID=(Invoke-WebRequest -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -UseBasicParsing).Content

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("admin_password", "$ADMIN_PASSWORD")
$DATA.Add("pcoip_registration_code", "$PCOIP_REGISTRATION_CODE")
$DATA.Add("safe_mode_admin_password", "$SAFE_MODE_ADMIN_PASSWORD")

# Retry function, defaults to trying for 5 minutes with 10 seconds intervals
function Retry([scriptblock]$Action, $Interval = 10, $Attempts = 30) {
  $Current_Attempt = 0

  while ($true) {
    $Current_Attempt++
    $rc = $Action.Invoke()

    if ($?) { return $rc }

    if ($Current_Attempt -ge $Attempts) {
        Write-Error "--> ERROR: Failed after $Current_Attempt attempt(s)." -InformationAction Continue
        Throw
    }

    Write-Information "--> Attempt $Current_Attempt failed. Retry in $Interval seconds..." -InformationAction Continue
    Start-Sleep -Seconds $Interval
  }
}

function Setup-CloudWatch {
    "################################################################"
    "Setting Up AWS CloudWatch..."
    "################################################################"
    Read-S3Object -BucketName $BUCKET_NAME -Key $CLOUDWATCH_SETUP_SCRIPT -File $CLOUDWATCH_SETUP_SCRIPT
    powershell .\$CLOUDWATCH_SETUP_SCRIPT `
        C:\ProgramData\Teradici\PCoIPAgent\logs\pcoip_agent*.txt "%Y%m%d%H%M%S" `
        $BASE_DIR\provisioning.log  "%Y%m%d%H%M%S" `
        $BASE_DIR\dc_new_ad_accounts.log "%Y%m%d%H%M%S"
}

function PCoIP-Agent-is-Installed {
    Get-Service "PCoIPAgent"
    return $?
}

function PCoIP-Agent-Install {
    "################################################################"
    "Installing PCoIP standard agent..."
    "################################################################"

    $agentInstallerDLDirectory = "$BASE_DIR"
    $pcoipAgentInstallerUrl = $PCOIP_AGENT_LOCATION_URL + '/' + $PCOIP_AGENT_FILENAME
    $destFile = $agentInstallerDLDirectory + '\' + $PCOIP_AGENT_FILENAME
    $wc = New-Object System.Net.WebClient

    "--> Downloading PCoIP standard agent from $pcoipAgentInstallerUrl..."
    Retry -Action {$wc.DownloadFile($pcoipAgentInstallerUrl, $destFile)}
    "--> Teradici PCoIP standard agent downloaded: $PCOIP_AGENT_FILENAME"

    "--> Installing Teradici PCoIP standard agent..."
    Start-Process -FilePath $destFile -ArgumentList "/S /nopostreboot _?$destFile" -PassThru -Wait

    if (!(PCoIP-Agent-is-Installed)) {
        "--> ERROR: Failed to install PCoIP standard agent."
        exit 1
    }

    "--> Teradici PCoIP standard agent installed successfully."
    $global:restart = $true
}

function PCoIP-Agent-Register {
    "################################################################"
    "Registering PCoIP agent..."
    "################################################################"

    cd 'C:\Program Files\Teradici\PCoIP Agent'

    "--> Checking for existing PCoIP License..."
    & .\pcoip-validate-license.ps1
    if ( $LastExitCode -eq 0 ) {
        "--> Found valid license."
        return
    }

    # License registration may have intermittent failures
    $Interval = 10
    $Timeout = 600
    $Elapsed = 0

    do {
        $Retry = $false
        & .\pcoip-register-host.ps1 -RegistrationCode $DATA."pcoip_registration_code"
        # the script already produces error message

        if ( $LastExitCode -ne 0 ) {
            if ($Elapsed -ge $Timeout) {
                "--> ERROR: Failed to register PCoIP agent."
                exit 1
            }

            "--> Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
            $Retry = $true
            Start-Sleep -Seconds $Interval
            $Elapsed += $Interval
        }
    } while ($Retry)

    "--> PCoIP agent registered successfully."
}

function Install-SSM {
    "################################################################"
    "Installing AWS Session Manager agent..."
    "################################################################"
    $wc = New-Object System.Net.WebClient

    "--> Downloading AWS Session Manager agent from $AWS_SSM_URL..."
    Retry -Action {$wc.DownloadFile($AWS_SSM_URL, $AWS_SSM_INSTALLER)}

    "--> Installing AWS Session Manager agent..."
    Start-Process -FilePath $AWS_SSM_INSTALLER -ArgumentList "/S /nopostreboot _?$AWS_SSM_INSTALLER" -PassThru -Wait

    "--> AWS Session Manager agent installed successfully."
    $global:restart = $true
}

function Schedule-AD-User-Creation {
    "################################################################"
    "Downloading AD accounts set-up script..."
    "################################################################"
    
    Set-Location -Path $BASE_DIR
    "--> Downloading $BUCKET_NAME\$DC_NEW_AD_ACCOUNTS_SCRIPT"
    Read-S3Object -BucketName $BUCKET_NAME -Key $DC_NEW_AD_ACCOUNTS_SCRIPT -File $DC_NEW_AD_ACCOUNTS_SCRIPT

    $ScriptPath = "$BASE_DIR\$DC_NEW_AD_ACCOUNTS_SCRIPT"
   
    # Schedule the task to run on system startup to execute a PowerShell script located at the path provided by '$ScriptPath'.
    # Random delay to avoid conflicts at startup with other system startup scripts, ensure a greater chance of success.
    schtasks /create /tn NewADProvision /sc onstart /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$ScriptPath'" /NP /DELAY 0002:00 /RU SYSTEM
}

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader
# Enforce TLS 1.2 for AWS deprecation of TLS prior versions from June,2023
# https://aws.amazon.com/blogs/security/tls-1-2-required-for-aws-endpoints/
# Adding TLS 1.2 for System.Net.WebClient class
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ([string]::IsNullOrWhiteSpace("$CUSTOMER_MASTER_KEY_ID")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key $CUSTOMER_MASTER_KEY_ID for secrets."
    Decrypt-Credentials
}

"--> Setting Administrator password..."
net user Administrator $DATA."admin_password" /active:yes

# SSM agent creates ssm-user account on the managed node when SSM agent starts,
# but this account isn't created automatically on Windows Server domain controller.
# To connect to domain controller using SSM, we create ssm-user for the SSM agent.
# More info can be found at https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html

if ([System.Convert]::ToBoolean("$AWS_SSM_ENABLE")) {

    #setting up aws-tags to check the status of DC provisioning
    New-EC2Tag -Resource $INSTANCEID -Tag @{Key="$TAG_NAME"; Value="Step 1/4 - Setting up AWS SSM..."}

    Install-SSM
    "================================================================"
    "Creating Local Account ssm-user For AWS Session Manager..."
    "================================================================"
    New-LocalUser -Name ssm-user -Description "local account for AWS Session Manager" -NoPassword
    "--> Assigning ssm-user to Administrators group"
    net localgroup "Administrators" "ssm-user" /add
}

if ([System.Convert]::ToBoolean("$CLOUDWATCH_ENABLE")) {
    New-EC2Tag -Resource $INSTANCEID -Tag @{Key="$TAG_NAME"; Value="Step 1/4 - Setting up Cloudwatch..."}
    Setup-CloudWatch
}

$DomainName = "$DOMAIN_NAME"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

New-EC2Tag -Resource $INSTANCEID -Tag @{Key="$TAG_NAME"; Value="Step 1/4 - Installing AD-Domain-Services..."}

"================================================================"
"Installing AD-Domain-Services..."
"================================================================"
# Installs the AD DS server role and installs the AD DS and AD LDS server
# administration tools, including GUI-based tools such as Active Directory Users
# and Computers and command-line tools such as dcdia.exe. No reboot required.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

New-EC2Tag -Resource $INSTANCEID -Tag @{Key="$TAG_NAME"; Value="Step 2/4 - Installing Forest and Configuring LDAPS..."}
"================================================================"
"Installing a new forest..."
"================================================================"
Install-ADDSForest -CreateDnsDelegation:$false `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $DATA."safe_mode_admin_password" -AsPlainText -Force) `
    -DatabasePath $DatabasePath `
    -SysvolPath $SysvolPath `
    -DomainName $DomainName `
    -DomainMode $DomainMode `
    -ForestMode $ForestMode `
    -InstallDNS:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true

"================================================================"
"Configuring LDAPS..."
"================================================================"
$DnsName = $env:COMPUTERNAME + "." + $DomainName
"--> Using DNS Name $DnsName..."
$myCert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation cert:\LocalMachine\My;
$thumbprint=($myCert.Thumbprint | Out-String).Trim();
$certStoreLoc = 'HKLM:\Software\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates';
if (!(Test-Path $certStoreLoc)) {
    New-Item $certStoreLoc -Force
}
Copy-Item -Path HKLM:\Software\Microsoft\SystemCertificates\My\Certificates\$thumbprint -Destination $certStoreLoc;

"================================================================"
"Uploading LDAPS Cert to Bucket..."
"================================================================"
# Save LDAPS Cert as a Base64 encoded DER certificate
$derCert = "$BASE_DIR\LdapsCert.der"
$pemCert = "$BASE_DIR\LdapsCert.pem"
$myCertLoc = 'cert:\LocalMachine\My\' + $thumbprint
Export-Certificate -Cert $myCertLoc -FilePath $derCert -Type CERT
certutil -encode $derCert $pemCert

# Upload to S3 Bucket
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet /passive
Write-S3Object -BucketName $BUCKET_NAME -File $pemCert -Key $LDAPS_CERT_FILENAME

Remove-Item -Path $derCert
Remove-Item -Path $pemCert

"================================================================"
"Delaying Active Directory Web Service (ADWS) start to avoid 1202 error..."
"================================================================"
sc.exe config ADWS start= delayed-auto

if ([System.Convert]::ToBoolean("$PCOIP_AGENT_INSTALL")) {
    if (PCoIP-Agent-is-Installed) {
        "--> PCoIP standard agent is already installed. Skipping..."
    } else {
        PCoIP-Agent-Install
    }

    if ( -not [string]::IsNullOrEmpty("$PCOIP_REGISTRATION_CODE") ) {
        PCoIP-Agent-Register
    }
}

"================================================================"
"Provisioning AD accounts script upon restart..."
"================================================================"
# Adds a task trigger to execute the ad_accounts setup script 
# post-restart which provisions admin users and domain users.
Schedule-AD-User-Creation

New-EC2Tag -Resource $INSTANCEID -Tag @{Key="$TAG_NAME"; Value="Step 3/4 - Restarting the computer..."}

"--> Restart PC for Install-ADDSForest"
Restart-Computer -Force
