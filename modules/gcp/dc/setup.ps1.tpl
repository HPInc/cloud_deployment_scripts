# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

$LOG_FILE = "C:\Teradici\provisioning.log"

$DECRYPT_URI = "https://cloudkms.googleapis.com/v1/${kms_cryptokey_id}:decrypt"

$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("safe_mode_admin_password", "${safe_mode_admin_password}")

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
        "--> Decrypting safe_mode_admin_password..."
        $resource = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $resource.Add("ciphertext", "${safe_mode_admin_password}")
        $response = Invoke-RestMethod -Method "Post" -Headers $headers -Uri $DECRYPT_URI -Body $resource
        $credsB64 = $response."plaintext"
        $DATA."safe_mode_admin_password" = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($credsB64))
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

$DomainName = "${domain_name}"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

"================================================================"
"Installing AD-Domain-Services..."
"================================================================"
# Installs the AD DS server role and installs the AD DS and AD LDS server
# administration tools, including GUI-based tools such as Active Directory Users
# and Computers and command-line tools such as dcdia.exe. No reboot required.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

"================================================================"
"Installing a new forest..."
"================================================================"
Install-ADDSForest -CreateDnsDelegation:$false `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $DATA."safe_mode_admin_password" -AsPlainText -Force) `
    -DatabasePath $DatabasePath `
    -SysvolPath $SysvolPath `
    -DomainName $DomainName `
    -DomainMode $DomainMode `
    -ForestMode $ForestMode `
    -InstallDNS:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true

"================================================================"
"Configuring LDAPS..."
"================================================================"
$DnsName = $env:COMPUTERNAME + "." + $DomainName
"--> Using DNS Name $DnsName..."
$myCert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation cert:\LocalMachine\My;
$thumbprint=($myCert.Thumbprint | Out-String).Trim();
$certStoreLoc = 'HKLM:\Software\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates';
if (!(Test-Path $certStoreLoc)) {
    New-Item $certStoreLoc -Force
}
Copy-Item -Path HKLM:\Software\Microsoft\SystemCertificates\My\Certificates\$thumbprint -Destination $certStoreLoc;

"================================================================"
"Delaying Active Directory Web Service (ADWS) start to avoid 1202 error..."
"================================================================"
sc.exe config ADWS start= delayed-auto 

"================================================================"
"Restarting computer..."
"================================================================"
Restart-Computer -Force
