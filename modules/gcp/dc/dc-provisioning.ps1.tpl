# Copyright Teradici Corporation 2019-2021;  © Copyright 2022 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

##### Template Variables #####
$BUCKET_NAME                 = "${bucket_name}"
$DOMAIN_NAME                 = "${domain_name}"
$GCP_OPS_AGENT_ENABLE        = "${gcp_ops_agent_enable}"
$KMS_CRYPTOKEY_ID            = "${kms_cryptokey_id}"
$OPS_SETUP_SCRIPT            = "${ops_setup_script}"
$PCOIP_AGENT_VERSION         = "${pcoip_agent_version}"
$PCOIP_REGISTRATION_CODE     = "${pcoip_registration_code}"
$SAFE_MODE_ADMIN_PASSWORD    = "${safe_mode_admin_password}"
$TERADICI_DOWNLOAD_TOKEN     = "${teradici_download_token}"

$LOG_FILE = "C:\Teradici\provisioning.log"
$PCOIP_AGENT_LOCATION_URL = "https://dl.teradici.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/raw/names/pcoip-agent-standard-exe/versions/$PCOIP_AGENT_VERSION"
$PCOIP_AGENT_FILENAME     = "pcoip-agent-standard_$PCOIP_AGENT_VERSION.exe"

$DECRYPT_URI = "https://cloudkms.googleapis.com/v1/$${KMS_CRYPTOKEY_ID}:decrypt"

$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
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

function Setup-Ops {
    "################################################################"
    "Running Ops Agent setup script from gs://$BUCKET_NAME/$OPS_SETUP_SCRIPT "
    "################################################################"
    if (Test-Path "C:\Program Files\Google\Cloud Operations\Ops Agent\config\config.yaml") {
        "--> Ops Agent configuration file already exists, skipping custom Ops Agent configuration to avoid overwriting existing settings"
    } else {
        Retry -Action {gsutil cp gs://$BUCKET_NAME/$OPS_SETUP_SCRIPT "C:\Teradici\"}
        
        powershell "C:\Teradici\$OPS_SETUP_SCRIPT" "C:\ProgramData\Teradici\PCoIPAgent\logs\pcoip_agent*.txt" `
                                                     "C:\Teradici\provisioning.log"
                                                    
    }
}

function Get-AuthToken {
    try {
        $response = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_AUTH_URI
        return $response."access_token"
    }
    catch {
        "--> ERROR: Failed to fetch auth token: $_"
        return $false
    }
}

function Decrypt-Credentials {
    $token = Get-AuthToken

    if(!($token)) {
        return $false
    }

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $($token)")

    try {
        "--> Decrypting safe_mode_admin_password..."
        $resource = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource.Add("ciphertext", "$SAFE_MODE_ADMIN_PASSWORD")
        $response = Invoke-RestMethod -Method "Post" -Headers $headers -Uri $DECRYPT_URI -Body $resource
        $credsB64 = $response."plaintext"
        $DATA."safe_mode_admin_password" = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($credsB64))

        "--> Decrypting pcoip_registration_code..."
        $resource = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource.Add("ciphertext", "$PCOIP_REGISTRATION_CODE")
        $response = Invoke-RestMethod -Method "Post" -Headers $headers -Uri $DECRYPT_URI -Body $resource
        $credsB64 = $response."plaintext"
        $DATA."pcoip_registration_code" = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($credsB64))
    }
    catch {
        "--> ERROR: Failed to decrypt credentials: $_"
        return $false
    }
}

function PCoIP-Agent-is-Installed {
    Get-Service "PCoIPAgent"
    return $?
}

function PCoIP-Agent-Install {
    "################################################################"
    "Installing PCoIP standard agent..."
    "################################################################"

    $agentInstallerDLDirectory = "C:\Teradici"
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
}

function PCoIP-Agent-Register {
    "################################################################"
    "Registering PCoIP agent..."
    "################################################################"

    cd 'C:\Program Files\Teradici\PCoIP Agent'

    "Checking for existing PCoIP License..."
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

Start-Transcript -path $LOG_FILE -append

if ([System.Convert]::ToBoolean("$GCP_OPS_AGENT_ENABLE")) {
    Setup-Ops
} 

"--> Script running as user '$(whoami)'."

if ([string]::IsNullOrWhiteSpace("$KMS_CRYPTOKEY_ID")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key $KMS_CRYPTOKEY_ID for secrets."
    Decrypt-Credentials
}

$DomainName = "$DOMAIN_NAME"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

"================================================================"
"Installing AD-Domain-Services..."
"================================================================"
# Installs the AD DS server role and installs the AD DS and AD LDS server
# administration tools, including GUI-based tools such as Active Directory Users
# and Computers and command-line tools such as dcdia.exe. No reboot required.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

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
"Delaying Active Directory Web Service (ADWS) start to avoid 1202 error..."
"================================================================"
sc.exe config ADWS start= delayed-auto 

if (PCoIP-Agent-is-Installed) {
    "--> PCoIP standard agent is already installed. Skipping..."
} else {
    PCoIP-Agent-Install
}

PCoIP-Agent-Register

"================================================================"
"Restarting computer..."
"================================================================"
Restart-Computer -Force
