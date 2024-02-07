# Copyright Teradici Corporation 2021;  © Copyright 2022-2024 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#############
# Variables #
#############
# REQUIRED: You must fill in these values before running the script
$PCOIP_REGISTRATION_CODE = ""

# OPTIONAL: You can use the default values set here or change them
$NVIDIA_DRIVER_FILENAME  = "472.39_grid_win10_win11_server2016_server2019_server2022_64bit_international.exe"
$NVIDIA_DRIVER_URL       = "https://storage.googleapis.com/nvidia-drivers-us-public/GRID/GRID13.1/"
$PCOIP_AGENT_VERSION     = "latest"
$TERADICI_DOWNLOAD_TOKEN = "yj39yHtgj68Uv2Qf"



$LOG_FILE = "C:\Teradici\provisioning.log"
$NVIDIA_DIR = "C:\Program Files\NVIDIA Corporation\NVSMI"

$PCOIP_AGENT_LOCATION_URL = "https://dl.anyware.hp.com/$TERADICI_DOWNLOAD_TOKEN/pcoip-agent/raw/names/pcoip-agent-graphics-exe/versions/$PCOIP_AGENT_VERSION"
$PCOIP_AGENT_FILENAME     = "pcoip-agent-graphics_$PCOIP_AGENT_VERSION.exe"

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
        Write-Error "--> ERROR: Failed after $Current_Attempt attempt(s)." -InformationAction Continue
        Throw
    }

    Write-Information "--> Attempt $Current_Attempt failed. Retrying in $Interval seconds..." -InformationAction Continue
    Start-Sleep -Seconds $Interval
  }
}

function Nvidia-is-Installed {
    if (!(test-path $NVIDIA_DIR)) {
        return $false
    }

    cd $NVIDIA_DIR
    & .\nvidia-smi.exe
    return $?
    return $false
}

function Nvidia-Install {
    "################################################################"
    "Installing NVIDIA driver..."
    "################################################################"

    if (Nvidia-is-Installed) {
        "--> NVIDIA driver is already installed. Skipping..."
        return
    }

    mkdir 'C:\Nvidia'
    $driverDirectory = "C:\Nvidia"

    $nvidiaInstallerUrl = $NVIDIA_DRIVER_URL + $NVIDIA_DRIVER_FILENAME
    $destFile = $driverDirectory + "\" + $NVIDIA_DRIVER_FILENAME
    $wc = New-Object System.Net.WebClient

    "--> Downloading NVIDIA GRID driver from $NVIDIA_DRIVER_URL..."
    Retry -Action {$wc.DownloadFile($nvidiaInstallerUrl, $destFile)}
    "--> NVIDIA GRID driver downloaded."

    "--> Installing NVIDIA GRID Driver..."
    $ret = Start-Process -FilePath $destFile -ArgumentList "/s /noeula /noreboot" -PassThru -Wait

    if (!(Nvidia-is-Installed)) {
        "--> ERROR: Failed to install NVIDIA GRID driver."
        exit 1
    }

    "--> NVIDIA GRID driver installed successfully."
    $global:restart = $true
}

function PCoIP-Agent-is-Installed {
    Get-Service "PCoIPAgent"
    return $?
}

function PCoIP-Agent-Install {
    "################################################################"
    "Installing PCoIP graphics agent..."
    "################################################################"

    $agentInstallerDLDirectory = "C:\Teradici"
    $pcoipAgentInstallerUrl = $PCOIP_AGENT_LOCATION_URL + '/' + $PCOIP_AGENT_FILENAME
    $destFile = $agentInstallerDLDirectory + '\' + $PCOIP_AGENT_FILENAME
    $wc = New-Object System.Net.WebClient

    "--> Downloading PCoIP graphics agent from $pcoipAgentInstallerUrl..."
    Retry -Action {$wc.DownloadFile($pcoipAgentInstallerUrl, $destFile)}
    "--> Teradici PCoIP graphics agent downloaded: $PCOIP_AGENT_FILENAME"

    "--> Installing Teradici PCoIP graphics agent..."
    Start-Process -FilePath $destFile -ArgumentList "/S /nopostreboot _?$destFile" -PassThru -Wait

    if (!(PCoIP-Agent-is-Installed)) {
        "--> ERROR: Failed to install PCoIP graphics agent."
        exit 1
    }

    "--> Teradici PCoIP graphics agent installed successfully."
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
        # The script already produces error message

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

function Audio-Enable {
    "--> Enabling audio service..."
    Get-Service | Where {$_.Name -match "AudioSrv"} | start-service
    Get-Service | Where {$_.Name -match "AudioSrv"} | set-service -StartupType "Automatic"
    Get-WmiObject -class win32_service -filter "Name='AudioSrv'"
}

if (Test-Path $LOG_FILE) {
    Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader
    "--> $LOG_FILE exists. Assuming this provisioning script has run, exiting..."
    exit 0
}

Start-Transcript -path $LOG_FILE -append

"--> Script running as user '$(whoami)'."

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    "--> Running as Administrator..."
} else {
    "--> Not running as Administrator..."
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Nvidia-Install

if (PCoIP-Agent-is-Installed) {
    "--> PCoIP graphics agent is already installed. Skipping..."
} else {
    PCoIP-Agent-Install
}

PCoIP-Agent-Register

Audio-Enable

if ($global:restart) {
    "--> Restart required. Restarting..."
    Restart-Computer -Force
} else {
    "--> No restart required."
}
