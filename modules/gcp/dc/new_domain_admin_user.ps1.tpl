# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Time values in seconds
$Interval = 10
$Timeout = 600
$Elapsed = 0

$LOG_FILE = "C:\Teradici\provisioning.log"

$DECRYPT_URI = "https://cloudkms.googleapis.com/v1/${kms_cryptokey_id}:decrypt"

$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("account_password", "${account_password}")

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

function Decrypt-Credentials {
    $token = Get-AuthToken

    if(!($token)) {
        return $false
    }

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $($token)")

    try {
        "--> Decrypting account_password..."
        $resource = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource.Add("ciphertext", "${account_password}")
        $response = Invoke-RestMethod -Method "Post" -Headers $headers -Uri $DECRYPT_URI -Body $resource
        $credsB64 = $response."plaintext"
        $DATA."account_password" = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($credsB64))
    }
    catch {
        "--> ERROR: Failed to decrypt credentials: $_"
        return $false
    }
}

Start-Transcript -path $LOG_FILE -append

if ([string]::IsNullOrWhiteSpace("${kms_cryptokey_id}")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key ${kms_cryptokey_id} for secrets."
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

        "--> Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
} while ($Retry)

# Service account needs to be in Domain Admins group for realm join to work on CentOS
Add-ADGroupMember -Identity "Domain Admins" -Members "${account_name}"
