# Copyright Teradici Corporation 2019-2021;  © Copyright 2022-2024 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

##### Template Variables #####
$BASE_DIR                    = "C:\Teradici"
$BUCKET_NAME                 = "${bucket_name}"
$DOMAIN_NAME                 = "${domain_name}"
$GCP_OPS_AGENT_ENABLE        = "${gcp_ops_agent_enable}"
$LDAPS_CERT_FILENAME         = "${ldaps_cert_filename}"
$LABEL_NAME                  = "${label_name}"
$OPS_SETUP_SCRIPT            = "${ops_setup_script}"
$PCOIP_AGENT_INSTALL         = "${pcoip_agent_install}"
$PCOIP_AGENT_VERSION         = "${pcoip_agent_version}"
$PCOIP_REGISTRATION_CODE_ID  = "${pcoip_registration_code_id}"
$TERADICI_DOWNLOAD_TOKEN     = "${teradici_download_token}"
$DC_NEW_AD_ACCOUNTS_SCRIPT   = "${dc_new_ad_accounts_script}"
$SAFE_MODE_ADMIN_PASSWORD_ID = "${safe_mode_admin_password_id}"
$LOG_FILE = "$BASE_DIR\provisioning.log"
$PCOIP_AGENT_LOCATION_URL = "https://dl.anyware.hp.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/raw/names/pcoip-agent-standard-exe/versions/$PCOIP_AGENT_VERSION"
$PCOIP_AGENT_FILENAME     = "pcoip-agent-standard_$PCOIP_AGENT_VERSION.exe"


$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$zone_name = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/zone
$instance_name = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/name

$pcoip_registration_code = & gcloud secrets versions access latest --secret=$PCOIP_REGISTRATION_CODE_ID --format="get(payload.data)" | 
ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

$safe_mode_admin_password = & gcloud secrets versions access latest --secret=$SAFE_MODE_ADMIN_PASSWORD_ID --format="get(payload.data)" |
ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

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
        Retry -Action {gsutil cp gs://$BUCKET_NAME/$OPS_SETUP_SCRIPT "$BASE_DIR"}
        
        powershell "$BASE_DIR\$OPS_SETUP_SCRIPT" "C:\ProgramData\Teradici\PCoIPAgent\logs\pcoip_agent*.txt" `
                                                     "$BASE_DIR\provisioning.log"
                                                    
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
        & .\pcoip-register-host.ps1 -RegistrationCode $pcoip_registration_code
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

function Update-Instance-Metadata {
    "################################################################"
    "Updating Instance Metadata..."
    "################################################################"

    $token = Get-AuthToken
    $headers = @{"Authorization" = "Bearer $($token)"; "Content-Type" = "application/json"}
    $zone_id = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/zone
    $instance_id = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/id

    # Retrieve information about the virtual machine instance using the API request.
    $compute_base_uri = "https://compute.googleapis.com/compute/v1/$zone_id/instances/$instance_id"
    $instance = Invoke-RestMethod -Method "Get" -Headers $headers -Uri $compute_base_uri

    # Remove the provisioning script from "windows-startup-script-url" key in the instance's metadata.
    $new_items = @(@{"key" = "windows-startup-script-url"; "value" = ""})
    $new_metadata = $instance."metadata".PsObject.Copy()

    # update the "items" property in the copied metadata with the new_items array.
    $new_metadata | Add-Member -NotePropertyName "items" -NotePropertyValue $new_items -Force
    $body = $new_metadata | ConvertTo-Json

    # Send an HTTP POST request to update the instance metadata using the constructed URI.
    Invoke-RestMethod -Method "Post" -Headers $headers -Uri $compute_base_uri/setMetadata -Body $body
}

function Schedule-AD-User-Creation {
    "################################################################"
    "Downloading AD accounts set-up script..."
    "################################################################"
    
    Set-Location -Path $BASE_DIR
    "--> Downloading $BUCKET_NAME\$DC_NEW_AD_ACCOUNTS_SCRIPT"
    gsutil cp gs://$BUCKET_NAME/$DC_NEW_AD_ACCOUNTS_SCRIPT "$BASE_DIR"

    $ScriptPath = "$BASE_DIR\$DC_NEW_AD_ACCOUNTS_SCRIPT"
   
    # Schedule the task to run on system startup to execute a PowerShell script located at the path provided by '$ScriptPath'.
    # Random delay to avoid conflicts at startup with other system startup scripts, ensure a greater chance of success.
    schtasks /create /tn NewADProvision /sc onstart /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$ScriptPath'" /NP /DELAY 0002:00 /RU SYSTEM
}

Start-Transcript -Path $LOG_FILE -Append

if ([System.Convert]::ToBoolean("$GCP_OPS_AGENT_ENABLE")) {
    gcloud compute instances add-labels $instance_name --zone $zone_name --labels=$LABEL_NAME=step1of3_setting-up-gcp-ops-agent
    Setup-Ops
} 

"--> Script running as user '$(whoami)'."

$DomainName = "$DOMAIN_NAME"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

gcloud compute instances add-labels $instance_name --zone $zone_name --labels=$LABEL_NAME=step1of3_installing-domain-services

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
    -SafeModeAdministratorPassword (ConvertTo-SecureString $safe_mode_admin_password -AsPlainText -Force) `
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

# Upload to GCS Bucket
Retry -Action {gsutil cp $pemCert gs://$BUCKET_NAME/$LDAPS_CERT_FILENAME}

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

    PCoIP-Agent-Register
}

"================================================================"
"Removing provisioning script from metadata..."
"================================================================"
# Modify the windows-startup-script-url in metadata to null value
# to prevent provisiong script from executing during subsequent 
# startup events.
Update-Instance-Metadata

"================================================================"
"Provisioning AD accounts script upon restart..."
"================================================================"
# Adds a task trigger to execute the ad_accounts setup script 
# post-restart which provisions admin users and domain users.
Schedule-AD-User-Creation

gcloud compute instances add-labels $instance_name --zone $zone_name --labels=$LABEL_NAME=step2of3_restarting-the-computer

"--> Restart PC for Install-ADDSForest"
Restart-Computer -Force
