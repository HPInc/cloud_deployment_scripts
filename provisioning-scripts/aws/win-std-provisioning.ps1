<powershell>
# Copyright Teradici Corporation 2021;  © Copyright 2022-2024 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#############
# Variables #
#############
# REQUIRED: You must fill in this value before running the script
$PCOIP_REGISTRATION_CODE = ""

# OPTIONAL: You can use the default values set here or change them
$PCOIP_AGENT_VERSION     = "latest"
$TERADICI_DOWNLOAD_TOKEN = "yj39yHtgj68Uv2Qf"


$LOG_FILE = "C:\Teradici\provisioning.log"

$PCOIP_AGENT_LOCATION_URL = "https://dl.anyware.hp.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/raw/names/pcoip-agent-standard-exe/versions/$PCOIP_AGENT_VERSION"
$PCOIP_AGENT_FILENAME     = "pcoip-agent-standard_$PCOIP_AGENT_VERSION.exe"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("pcoip_registration_code", "$PCOIP_REGISTRATION_CODE")

$global:restart = $false

# Retry function, defaults to trying for 5 minutes with 10 seconds intervals
function Retry([scriptblock]$Action, $Interval = 10, $Attempts = 30) {
    $Current_Attempt = 0

    while ($true) {
      $Current_Attempt++
      $rc = $Action.Invoke()

      if ($?) { return $rc }

      if ($Current_Attempt -ge $Attempts) {
          Write-Error "Failed after $Current_Attempt attempt(s)." -InformationAction Continue
          Throw
      }

      Write-Information "Attempt $Current_Attempt failed. Retry in $Interval seconds..." -InformationAction Continue
      Start-Sleep -Seconds $Interval
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

            "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
            $Retry = $true
            Start-Sleep -Seconds $Interval
            $Elapsed += $Interval
        }
    } while ($Retry)

    "--> PCoIP agent registered successfully."
}

if (Test-Path $LOG_FILE) {
    Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

    "--> $LOG_FILE exists. Assuming this provisioning script had ran, exiting..."

    exit 0
}

function Audio-Enable {
    "--> Enabling audio service..."
    Get-Service | Where {$_.Name -match "AudioSrv"} | start-service
    Get-Service | Where {$_.Name -match "AudioSrv"} | set-service -StartupType "Automatic"
    Get-WmiObject -class win32_service -filter "Name='AudioSrv'"
}

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

"--> Script running as user '$(whoami)'."

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    "--> Running as Administrator..."
} else {
    "--> Not running as Administrator..."
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

if (PCoIP-Agent-is-Installed) {
    "--> PCoIP standard agent is already installed. Skipping..."
} else {
    PCoIP-Agent-Install
}

if ( -not [string]::IsNullOrEmpty("$PCOIP_REGISTRATION_CODE") ) {
    PCoIP-Agent-Register
}

Audio-Enable

if ($global:restart) {
    "--> Restart required. Restarting..."
    Restart-Computer -Force
} else {
    "--> No restart required."
}

</powershell>
<persist>true</persist>
