# Time values in seconds
$Interval = 10
$Timeout = 600
$Elapsed = 0

Write-Output "================================================================"
Write-Output "Creating new service account..."
Write-Output "================================================================"

do {
    Try {
        $Retry = $false
        New-AdUser -Name "${account_name}" -AccountPassword (ConvertTo-SecureString "${account_password}" -AsPlainText -Force) -Enabled:$true 
    }
    Catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
        $_.Exception.Message

        if ($Elapsed -ge $Timeout) {
            exit
        }

        "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
} while ($Retry)
