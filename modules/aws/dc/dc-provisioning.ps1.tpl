# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

$LOG_FILE = "C:\Teradici\provisioning.log"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("safe_mode_admin_password", "${safe_mode_admin_password}")

function Setup-CloudWatch {
    "################################################################"
    "Setting Up AWS CloudWatch..."
    "################################################################"
    Read-S3Object -BucketName ${bucket_name} -Key ${cloudwatch_setup_script} -File ${cloudwatch_setup_script}
    powershell .\${cloudwatch_setup_script} C:\Teradici\provisioning.log "%Y%m%d%H%M%S"
}

function Decrypt-Credentials {
    try {
        "--> Decrypting safe_mode_admin_password..."
        $ByteAry = [System.Convert]::FromBase64String("${safe_mode_admin_password}")
        $MemStream = New-Object System.IO.MemoryStream($ByteAry, 0, $ByteAry.Length)
        $DecryptResp = Invoke-KMSDecrypt -CiphertextBlob $MemStream 
        $StreamRead = New-Object System.IO.StreamReader($DecryptResp.Plaintext)
        $DATA."safe_mode_admin_password" = $StreamRead.ReadToEnd()
    }
    catch {
        "--> ERROR: Failed to decrypt credentials: $_"
        return $false
    }
}

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

Setup-CloudWatch

if ([string]::IsNullOrWhiteSpace("${customer_master_key_id}")) {
    "--> Script is not using encryption for secrets."
} else {
    "--> Script is using encryption key ${customer_master_key_id} for secrets."
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
