# Copyright (c) 2021 Teradici Corporation

# Setup the AWS CloudWatch Logs agent for an EC2 instance.
# Array with the following information is required:
#   1. Log file path
#   2. DateTime format


$AWSLOGS_LOG_FILE    = "C:\Teradici\awslogs-setup.log"

$CLOUDWATCH_AGENT_INSTALLER_URL = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
$CLOUDWATCH_AGENT_INSTALLER     = "amazon-cloudwatch-agent.msi"
$CLOUDWATCH_AGENT_DIR           = "C:\Program Files\Amazon\AmazonCloudWatchAgent"

$AWSLOGS_CONFIG_FILE = "awslogs_config.json"
$AWSLOGS_CONFIG_PATH = "C:\Program Files\Amazon\AmazonCloudWatchAgent\awslogs_config.json"

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

function Add-AWSLogs-Config($log_file_path, $datetime_format){
    $log_file_name=(Get-Item $log_file_path).Basename

    $c = @{
        "file_path"=$log_file_path;
        "log_group_name"=$global:instance_name;
        "log_stream_name"=$log_file_name;
        "timestamp_format"=$datetime_format;
        "timezone"="LOCAL";
        "multi_line_start_pattern"="{timestamp_format}";
        "encoding"="ascii";
    }
    $global:collect_list+=$c
}

function Write-AWSLogs-Config {
    $files = "" | Select collect_list
    $files.collect_list = $global:collect_list

    $logs_collected = @{}
    $logs_collected.Add("files", $files)

    $logs = @{}
    $logs.Add("logs_collected", $logs_collected)

    $configurations = @{}
    $configurations.Add("logs", $logs)

    New-Item -itemType File -Path $CLOUDWATCH_AGENT_DIR -Name $AWSLOGS_CONFIG_FILE
    Retry -Action {$configurations | ConvertTo-JSON -Dept 10| Out-File $AWSLOGS_CONFIG_PATH -Encoding Ascii -Force}
}

Start-Transcript -Path $AWSLOGS_LOG_FILE -Append -IncludeInvocationHeader

"--> Downloading CloudWatch Logs Agent from $CLOUDWATCH_AGENT_INSTALLER_URL..."
$wc = New-Object System.Net.WebClient
Retry -Action {$wc.DownloadFile($CLOUDWATCH_AGENT_INSTALLER_URL, $CLOUDWATCH_AGENT_INSTALLER)}

"--> Installing CloudWatch Logs Agent..."
msiexec /i $CLOUDWATCH_AGENT_INSTALLER

"--> Configuring CloudWatch Agent..."
$instance_id = Retry -Action {Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id | Select-Object -ExpandProperty Content}

while ($global:instance_name -eq $null) {
    $global:instance_name = Get-EC2Tag -Filter @{Name="resource-id";Value=$instance_id} | Select-Object -ExpandProperty Value
}

$global:collect_list = @()
for ( $i = 0; $i -lt $args.count; $i++ ) {
    Add-AWSLogs-Config -log_file_path $args[$i] -datetime_format $args[++$i]
}

"--> Writing configurations to $AWSLOGS_CONFIG_PATH..."
Write-AWSLogs-Config

"--> Starting CloudWatch Agent..."
& "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -s -c file:$AWSLOGS_CONFIG_PATH
" "

