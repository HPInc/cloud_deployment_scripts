# Time values in seconds
$Interval = 10
$Timeout = 600
$Elapsed = 0

Write-Output "================================================================"
Write-Output "Creating new AD Domain Admin account ${account_name}..."
Write-Output "================================================================"

do {
    Try {
        $Retry = $false
        New-AdUser -Name "${account_name}" -AccountPassword (ConvertTo-SecureString "${account_password}" -AsPlainText -Force) -Enabled:$true 
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

