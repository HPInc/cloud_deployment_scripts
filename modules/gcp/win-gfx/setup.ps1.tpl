if (test-path "C:\Nvidia") {
    exit
}

"################################################################"
"Downloading NVIDIA GRID Driver..."
"################################################################"
mkdir 'C:\Nvidia'
$driverDirectory = "C:\Nvidia"
$driverUrl = "${nvidia_driver_location}" + "${nvidia_driver_filename}"
$destFile = $driverDirectory + "\" + "${nvidia_driver_filename}"
(New-Object System.Net.WebClient).DownloadFile($driverUrl, $destFile)
"NVIDIA GRID Driver downloaded"

"################################################################"
"Installing NVIDIA GRID Driver..."
"################################################################"
$ret = Start-Process -FilePath $destFile -ArgumentList "/s /noeula /noreboot" -PassThru -Wait
"NVIDIA GRID Driver installed"

"################################################################"
"Downloading Teradici PCoIP Agent..."
"################################################################"
mkdir 'C:\Teradici'
$agentInstallerDLDirectory = "C:\Teradici"
if ("${pcoip_agent_filename}") {
    $agent_filename = "${pcoip_agent_filename}"
} else {
    $agent_filename = (New-Object System.Net.WebClient).DownloadString("${pcoip_agent_location}latest-graphics-agent.json") | ConvertFrom-Json | Select-Object -ExpandProperty "filename"
}
$pcoipAgentInstallerUrl = "${pcoip_agent_location}$agent_filename"
$destFile = $agentInstallerDLDirectory + '\' + $agent_filename
(New-Object System.Net.WebClient).DownloadFile($pcoipAgentInstallerUrl, $destFile)
"Teradici PCoIP Agent downloaded: $agent_filename"

"################################################################"
"Installing Teradici PCoIP Agent..."
"################################################################"
$ret = Start-Process -FilePath $destFile -ArgumentList "/S /nopostreboot" -PassThru -Wait
"Teradici PCoIP Agent installed"

"################################################################"
"Registering PCoIP Agent..."
"################################################################"
cd 'C:\Program Files\Teradici\PCoIP Agent'
& .\pcoip-register-host.ps1 -RegistrationCode "${pcoip_registration_code}"
"PCoIP Agent Registered"

"################################################################"
"Joining Domain ${domain_name}..."
"################################################################"
$interface = (Get-DNSClientServerAddress -AddressFamily "IPv4" | Where-Object {$_.ServerAddresses.Count -gt 0} | Where-Object InterfaceAlias -notlike "*${gcp_project_id}*").InterfaceAlias
Set-DNSClientServerAddress -InterfaceAlias $interface -ServerAddresses "${domain_controller_ip}"
$username = "${service_account_username}" + "@" + "${domain_name}"
$password = ConvertTo-SecureString "${service_account_password}" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $password)

# Looping in case Domain Controller is not yet available
$Interval = 10
$Timeout = 600
$Elapsed = 0

do {
    Try {
        $Retry = $false
        # Don't do -Restart here because there is no log showing the restart
        Add-Computer -DomainName "${domain_name}" -Credential $cred -Verbose -Force -ErrorAction Stop
    }

    # The same Error, System.InvalidOperationException, is thrown in these cases: 
    # - when Domain Controller not reachable (retry waiting for DC to come up)
    # - when password is incorrect (retry because user might not be added yet)
    # - when computer is already in domain
    Catch [System.InvalidOperationException] {
        $_.Exception.Message
        if (($Elapsed -ge $Timeout) -or ($_.Exception.GetType().FullName -match "AddComputerToSameDomain,Microsoft.PowerShell.Commands.AddComputerCommand")) {
            exit
        }

        "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
        $Retry = $true
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
    }
    Catch {
        $_.Exception.Message
        exit
    }
} while ($Retry)

"################################################################"
"Restarting computer..."
"################################################################"
Restart-Computer -Force