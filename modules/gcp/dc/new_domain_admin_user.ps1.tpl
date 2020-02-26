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
        "Error fetching auth token: $_"
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
        $resource = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource.Add("ciphertext", "${account_password}")
        $response = Invoke-RestMethod -Method "Post" -Headers $headers -Uri $DECRYPT_URI -Body $resource
        $credsB64 = $response."plaintext"
        $DATA."account_password" = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($credsB64))
    }
    catch {
        "Error decrypting credentials: $_"
        return $false
    }
}

Start-Transcript -path $LOG_FILE -append

if ([string]::IsNullOrWhiteSpace("${kms_cryptokey_id}")) {
    "Not using encryption"
} else {
    "Using ecnryption key ${kms_cryptokey_id}"
    Decrypt-Credentials
}

Write-Output "================================================================"
Write-Output "Creating new AD Domain Admin account ${account_name}..."
Write-Output "================================================================"

do {
    Try {
        $Retry = $false
        New-AdUser -Name "${account_name}" -AccountPassword (ConvertTo-SecureString $DATA."account_password" -AsPlainText -Force) -Enabled $True -PasswordNeverExpires $True
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
