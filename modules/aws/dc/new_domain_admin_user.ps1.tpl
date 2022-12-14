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

function Decrypt-Credentials {
    try {
        "--> Decrypting account_password..."
        $ByteAry = [System.Convert]::FromBase64String("${account_password}")
        $MemStream = New-Object System.IO.MemoryStream($ByteAry, 0, $ByteAry.Length)
        $DecryptResp = Invoke-KMSDecrypt -CiphertextBlob $MemStream 
        $StreamRead = New-Object System.IO.StreamReader($DecryptResp.Plaintext)
        $DATA."account_password" = $StreamRead.ReadToEnd()
    }
    catch {
        "--> ERROR: Failed to decrypt credentials: $_"
        return $false
    }
}

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

if ([string]::IsNullOrWhiteSpace("${customer_master_key_id}")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key ${customer_master_key_id} for secrets."
    Decrypt-Credentials
}

"================================================================"
"Creating new AD Domain Admin account ${account_name}..."
"================================================================"
do {
    Try {
        $Retry = $false
        New-ADUser `
            -Name "${account_name}" `
            -UserPrincipalName "${account_name}@${domain_name}" `
            -Enabled $True `
            -PasswordNeverExpires $True `
            -AccountPassword (ConvertTo-SecureString $DATA."account_password" -AsPlainText -Force)
    }
    Catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
        "--> $($_.Exception.Message)"

        if ($Elapsed -ge $Timeout) {
            "--> ERROR: Timed out trying to create new AD acccount, exiting..."
            exit 1
        }

        "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
} while ($Retry)

# Service account needs to be in Domain Admins group for realm join to work on CentOS
Add-ADGroupMember -Identity "Domain Admins" -Members "${account_name}"
