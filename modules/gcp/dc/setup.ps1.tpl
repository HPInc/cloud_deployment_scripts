# Make sure this file has Windows line endings

$DomainName = "${domain_name}"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

Write-Output "================================================================"
Write-Output "Installing AD-Domain-Services..."
Write-Output "================================================================"

# Installs the AD DS server role and installs the AD DS and AD LDS server
# administration tools, including GUI-based tools such as Active Directory Users
# and Computers and command-line tools such as dcdia.exe. No reboot required.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Output "================================================================"
Write-Output "Install a new forest..."
Write-Output "================================================================"
Install-ADDSForest -CreateDnsDelegation:$false `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "${safe_mode_admin_password}" -AsPlainText -Force) `
    -DatabasePath $DatabasePath `
    -SysvolPath $SysvolPath `
    -DomainName $DomainName `
    -DomainMode $DomainMode `
    -ForestMode $ForestMode `
    -InstallDNS:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true

Write-Output "================================================================"
Write-Output "Configuring LDAPS..."
Write-Output "================================================================"
$DnsName = $env:COMPUTERNAME + "." + $DomainName
$myCert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation cert:\LocalMachine\My;
$thumbprint=($myCert.Thumbprint | Out-String).Trim();
$certStoreLoc = 'HKLM:\Software\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates';
if (!(Test-Path $certStoreLoc)) {
    New-Item $certStoreLoc -Force
}
Copy-Item -Path HKLM:\Software\Microsoft\SystemCertificates\My\Certificates\$thumbprint -Destination $certStoreLoc;

Write-Output "================================================================"
Write-Output "Delay Active Directory Web Service (ADWS) start to avoid 1202 error..."
Write-Output "================================================================"
sc.exe config ADWS start= delayed-auto 

Write-Output "================================================================"
Write-Output "Restarting computer..."
Write-Output "================================================================"

Restart-Computer -Force
