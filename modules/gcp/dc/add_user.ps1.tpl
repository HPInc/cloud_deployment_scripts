# Time values in seconds
$Interval = 5
$Timeout = 600
$Elapsed = 0

Write-Output "================================================================"
Write-Output "Adding new svcaccount user..."
Write-Output "================================================================"

do {
    Try {
        $Retry = $false
        New-AdUser -Name "${account_name}" -AccountPassword (ConvertTo-SecureString "${account_password}" -AsPlainText -Force) -Enabled:$true 
    }
    Catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
        if ($Elapsed -ge $Timeout) {
            throw $_
        }

        "$($_.Exception.Message)  Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
} while ($Retry)
