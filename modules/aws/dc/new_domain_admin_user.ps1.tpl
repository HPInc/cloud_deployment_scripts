# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Time values in seconds
$Interval = 10
$Timeout = 600
$Elapsed = 0

$LOG_FILE = "C:\Teradici\provisioning.log"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("account_password", "${account_password}")

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

"Not using encryption"

Write-Output "================================================================"
Write-Output "Creating new AD Domain Admin account ${account_name}..."
Write-Output "================================================================"

do {
    Try {
        $Retry = $false
        New-AdUser -Name "${account_name}" -AccountPassword (ConvertTo-SecureString $DATA."account_password" -AsPlainText -Force) -Enabled:$true 
    }
    Catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
        $_.Exception.Message

        if ($Elapsed -ge $Timeout) {
            Write-Output "Error: Timed out trying to create new AD acccount."
            exit
        }

        "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
} while ($Retry)

# Service account needs to be in Domain Admins group for realm join to work on CentOS
Add-ADGroupMember -Identity "Domain Admins" -Members "${account_name}"
