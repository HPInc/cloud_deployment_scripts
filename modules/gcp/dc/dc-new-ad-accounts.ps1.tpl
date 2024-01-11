# Copyright 2023 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Time values in seconds
$Interval = 10
$Timeout = 600
$Elapsed = 0
$BASE_DIR = "C:\Teradici"
# Setup-CloudWatch will track this log file.
$LOG_FILE = "$BASE_DIR\dc_new_ad_accounts.log"

$DECRYPT_URI = "https://cloudkms.googleapis.com/v1/${kms_cryptokey_id}:decrypt"

$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$zone_name = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/zone
$instance_name = Invoke-RestMethod -Method "Get" -Headers $METADATA_HEADERS -Uri $METADATA_BASE_URI/name

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

Start-Transcript -Path $LOG_FILE -Append

if ([string]::IsNullOrWhiteSpace("${kms_cryptokey_id}")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key ${kms_cryptokey_id} for secrets."
    Decrypt-Credentials
}

gcloud compute instances add-labels $instance_name --zone $zone_name --labels=${label_name}=step3of3_creating-new-ad-domain-admin-accounts

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
        "--> Added AD Domain Admin User $account_name"
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

if ("${csv_file}" -ne "") {
    "================================================================"
    "Creating new AD Domain Users from CSV file..."
    "================================================================"

    gcloud compute instances add-labels $instance_name --zone $zone_name --labels=${label_name}=step3of3_creating-new-domain-users

    Write-Host " --> Downloading file from bucket..."
    # Download domain users list.
    gsutil cp gs://${bucket_name}/${csv_file} "$BASE_DIR"

    #Store the data from ADUsers.csv in the $ADUsers variable
    $ADUsers = Import-csv "$BASE_DIR\${csv_file}"

    #Loop through each row containing user details in the CSV file
    foreach ($User in $ADUsers) {
        #Read user data from each field in each row and assign the data to a variable as below
        $Username 	= $User.username
        $Password 	= $User.password
        $Firstname 	= $User.firstname
        $Lastname 	= $User.lastname
        $Isadmin        = $User.isadmin

        #Check to see if the user already exists in AD
        if (Get-ADUser -F {SamAccountName -eq $Username}) {
            #If user does exist, give a warning
            "--> WARNING: A user account with username $Username already exists in Active Directory."
        }
        else {
            #User does not exist then proceed to create the new user account

            #Account will be created in the OU provided by the $OU variable read from the CSV file
            New-ADUser `
                -SamAccountName $Username `
                -UserPrincipalName "$Username@${domain_name}" `
                -Name "$Firstname $Lastname" `
                -GivenName $Firstname `
                -Surname $Lastname `
                -Enabled $True `
                -DisplayName "$Lastname, $Firstname" `
                -AccountPassword (convertto-securestring $Password -AsPlainText -Force) -ChangePasswordAtLogon $False

            if ($Isadmin -eq "true") {
                Add-ADGroupMember `
                    -Identity "Domain Admins" `
                    -Members $Username
            }
            "--> Added AD User $Username..."
        }
    }
    del "$BASE_DIR\${csv_file}"
}

# Unregister the scheduled job
schtasks /delete /tn NewADProvision /f

gcloud compute instances add-labels $instance_name --zone $zone_name --labels=${label_name}=${final_status}
