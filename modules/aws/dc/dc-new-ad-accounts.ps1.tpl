# Copyright 2023 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Time values in seconds
$Interval = 10
$Timeout = 300
$Elapsed = 0
$BASE_DIR = "C:\Teradici"
# Setup-CloudWatch will track this log file.
$LOG_FILE = "$BASE_DIR\dc_new_ad_accounts.log"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("ad_service_account_password", "${ad_service_account_password}")
$INSTANCEID=(Invoke-WebRequest -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -UseBasicParsing).Content

function Decrypt-Credentials {
    try {
        "--> Decrypting ad_service_account_password..."
        $ByteAry = [System.Convert]::FromBase64String("${ad_service_account_password}")
        $MemStream = New-Object System.IO.MemoryStream($ByteAry, 0, $ByteAry.Length)
        $DecryptResp = Invoke-KMSDecrypt -CiphertextBlob $MemStream
        $StreamRead = New-Object System.IO.StreamReader($DecryptResp.Plaintext)
        $DATA."ad_service_account_password" = $StreamRead.ReadToEnd()
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

New-EC2Tag -Resource $INSTANCEID -Tag @{Key="${tag_name}"; Value="Step 4/4 - Creating new AD Domain Admin accounts..."}

"================================================================"
"Creating new AD Domain Admin account ${ad_service_account_username}..."
"================================================================"
do {
    Try {
        $Retry = $false
        New-ADUser `
            -Name "${ad_service_account_username}" `
            -UserPrincipalName "${ad_service_account_username}@${domain_name}" `
            -Enabled $True `
            -PasswordNeverExpires $True `
            -AccountPassword (ConvertTo-SecureString $DATA."ad_service_account_password" -AsPlainText -Force)
        "--> Added AD Domain Admin User $ad_service_account_username"
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
Add-ADGroupMember -Identity "Domain Admins" -Members "${ad_service_account_username}"

if ("${csv_file}" -ne "") {
    "================================================================"
    "Creating new AD Domain Users from CSV file..."
    "================================================================"

    Write-Host " --> Downloading file from bucket..."
    # Download domain users list.
    Read-S3Object -BucketName ${bucket_name} -Key ${csv_file} -File "$BASE_DIR\${csv_file}"
    
    New-EC2Tag -Resource $INSTANCEID -Tag @{Key="${tag_name}"; Value="Step 4/4 - Creating new AD Domain Users from CSV file..."}

    #Store the data from ADUsers.csv in the $ADUsers variable
    $ADUsers = Import-csv "$BASE_DIR\${csv_file}"

    #Loop through each row containing user details in the CSV file
    foreach ($User in $ADUsers) {
        #Read user data from each field in each row and assign the data to a variable as below
        $Username  = $User.username
        $Password  = $User.password
        $Firstname = $User.firstname
        $Lastname  = $User.lastname
        $Isadmin   = $User.isadmin

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

New-EC2Tag  -Resource $INSTANCEID -Tag @{Key="${tag_name}"; Value="${final_status}"}
