# © Copyright 2022 HP Development Company, L.P.

# GCP Agent Policies enable automated installation and maintenance of the Google Cloud's operations suite agents across 
# a fleet of VMs that match user-specified criteria. Investigated into creating Agent Policy using Terraform on Feb 8, 2022, 
# but Agent Policy couldn't be created even though all system requirements were met, and required roles were assigned to 
# the service account. Needs further investigation, please see the doc for creating Agent Policy using automation tools at:
# https://registry.terraform.io/modules/terraform-google-modules/cloud-operations/google/latest/submodules/agent-policy

# Setup the GCP Ops Agent for a VM instance.
# Array with Log file path is required as parameter(s). e.g. powershell ops_setup_win.ps1 "C:\a.log" "C:\b.log"

$OPS_AGENT_CONF_PATH     = "C:\Program Files\Google\Cloud Operations\Ops Agent\config"
$OPS_AGENT_DIR           = "C:\Program Files\Google"
$OPS_AGENT_DIR_INSTALL   = "C:\'Program Files'\Google"
# Please see the Ops Agent download link at: https://cloud.google.com/logging/docs/agent/ops-agent/installation#agent-install-latest-windows
$OPS_AGENT_INSTALLER_URL = "https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.ps1"
$OPS_AGENT_INSTALLER     = Split-Path $OPS_AGENT_INSTALLER_URL -leaf
$OPS_LOG_FILE            = "C:\Teradici\ops-setup.log"

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

# To build structure of logging receivers and logging pipelines. 
# Please see the following link for more info about Ops Agent configuration:
# https://cloud.google.com/logging/docs/agent/ops-agent/configuration
# Log file path is required as parameter. e.g. Add-Ops-Config -log_file_path "C:\a.log"
function Add-Ops-Config($log_file_path) {
  # Attempted to use log file full path as log name, but received an error message "Received unexpected value parsing name"
  # So we replace / with - as a workaround. Need to investigate about using full path as log name since 
  # got the following message when trying to escape character: 
  # "Log name contains illegal character. Allowed characters are alphanumerics and ./_-"
  $receiver_id = $log_file_path -replace '[:]',"" -replace '\\','-' 

  $c="${receiver_id}:
      type: files
      include_paths:
      - ${log_file_path}
   "

  $global:collect_list += $c
  $global:receivers_list += $receiver_id
}

function Write-OPS-Config {
  $config_file_name = "config.yaml"

  $configuration="logging:
  receivers:
    $collect_list
  service:
    pipelines:
      custom_pipeline:
        receivers: [$receivers_list]
metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
  processors:
    metrics_filter:
      type: exclude_metrics
      metrics_pattern: []
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
        processors: [metrics_filter]" 

  Retry -Action {$configuration | Out-File "$OPS_AGENT_CONF_PATH\$config_file_name" -Encoding Ascii -Force}
}

Start-Transcript -Path $OPS_LOG_FILE -Append -IncludeInvocationHeader

"--> Downloading OPS Agent from $OPS_AGENT_INSTALLER_URL..."
$wc = New-Object Net.WebClient
Retry -Action {$wc.DownloadFile($OPS_AGENT_INSTALLER_URL, "$OPS_AGENT_DIR\$OPS_AGENT_INSTALLER")}
"--> OPS Agent has been downloaded"

"--> Installing OPS Agent..."
Invoke-Expression "$OPS_AGENT_DIR_INSTALL\$OPS_AGENT_INSTALLER -AlsoInstall"

"--> Configuring OPS Agent..."

$global:collect_list = @()
$global:receivers_list = @()
for ( $i = 0; $i -lt $args.count; $i+=1 ) {
    Add-Ops-Config -log_file_path $args[$i]
    if ( $i -ne ($args.count-1) ) {
	    $global:receivers_list += ","
  }
}

"--> Writing configurations..."
Write-Ops-config

"--> Starting OPS Agent..."
Retry -Action {Restart-Service google-cloud-ops-agent -Force}
"--> OPS Agent is running..."