# Troubleshooting

## Table of Contents
1. [Connecting to VMs Using SSH/RDP](#connecting-to-vms-using-ssh/rdp)
    1. [Connecting to CentOS Workstations](#connecting-to-centos-workstations)
    2. [Connecting to Windows Workstations](#connecting-to-windows-workstations)
2. [VM Log Locations](#vm-log-locations)
    1. [Amazon Web Services](#amazon-web-services)
    2. [Google Cloud Platform](#google-cloud-platform)
3. [CAS Connector Missing](#anyware-connector-missing)
4. [Failed to SSH into VMs](#failed-to-ssh-into-vms)
    1. [Local Machine](#local-machine)
    2. [GCP Console](#gcp-console)

---

### Accessing VMs
- For troubleshooting deployments, access to the VMs is available for debugging and log file inspection.
- By default, AWS VMs are accessible via AWS Systems Manager (SSM), whereas GCP VM instances can be accessed through the Identity-Aware Proxy (IAP).

### Connecting to AWS VM Instances Using AWS Systems Manager (SSM)
- SSM is enabled by default on all AWS VM instances, allowing access to all VM instances via AWS Systems Manager (SSM), unless `enable_ssm` is set to false in `terraform.tfvars`.
- To access VM Instance's through SSM, please refer to this link - https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html

### Connecting to GCP VM Instances using Identity-Aware Proxy (IAP)
- IAP is enabled by default on all GCP VM instances, allowing access to all VM instances via Identity-Aware Proxy (IAP), unless `gcp_iap_enable` is set to false in `terraform.tfvars`.
- To access VM Instance's through IAP, please refer to this link - https://cloud.google.com/iap/docs/using-tcp-forwarding

### Alternative ways to connect to VMs
- Should IAP or SSM be unavailable or intentionally disabled, SSH or RDP clients can be utilized for VM access.
- Direct SSH/RDP access to AWS or GCP VM instances from the machine executing Terraform is contingent upon setting the `enable_ssh` or `enable_rdp` variables to true within the `terraform.tfvars` file.
- Workstation VMs, not having public IPs, remain inaccessible from the internet. However, a bastion host—like the DC or Connector—provides a bridge to access Workstation VMs within the private network.
- For public IP access to workstation VMs, set the `enable_workstation_public_ip` to true in the `terraform.tfvars` file.
- Additionally, ensure the activation of SSH or RDP by setting the `enable_ssh` or `enable_rdp` variables respectively.

### Connecting to CentOS Workstations
- One way to access CentOS Workstations is to use the Connector as a bastion host. Please refer to the log tables below for the corresponding <login-user> for each VM.
- Use the -i flag to provide SSH with the private key that pairs with the public keys specified in terraform.tfvars.
- For GCP, enter the private key path that pairs with awc_admin_ssh_pub_key_file for the Connector or centos_admin_ssh_pub_key_file for CentOS Workstations.
- For AWS, enter the private key path that pairs with admin_ssh_pub_key_file for the Connector and CentOS Workstations.

Execute the following command to first SSH into the Connector:

```ssh -A -i </path/to/ssh-private-key> <login-user>@<awc-public-ip>```

From inside the Connector, execute the following command to SSH into the CentOS Workstation:

```ssh <login-user>@<centos-internal-ip>```

### Connecting to Windows Workstations
One way to access Windows Workstations is to use the Domain Controller as a bastion host. Use the following credentials to connect to the DC using a RDP client:

```
Computer: <domain-controller-public-ip>
User: Administrator
Password: <dc_admin_password_set_in_terraform.tfvars>
```

From inside the Domain Controller, connect to the Windows Workstation by using Windows RDP and entering the following login credentials:

```
Computer: <win-internal-ip>
User: Administrator
Password: <dc_admin_password_set_in_terraform.tfvars>
```

## VM Log Locations

### Amazon Web Services

| VM Instance      | Login User    | Log File Path                               | Description                                                 |
| :--------------- | :------------ | :------------------------------------------ | :---------------------------------------------------------- |
| awc              | rocky         | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/awc-install.log           | Detailed log for AWC installation                           |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/anyware-connector/configure.log    | (duplicate log from awc-install.log)                        |
| awm              | rocky         | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/awm-install.log           | Detailed log for Anyware Manager installation               |
|                  |               | /var/log/anyware-manager/install.log        | (duplicate log from awm-install.log )                       |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
| centos-gfx       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
| lls              | rocky         | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
| ha               | rocky         | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
| dc               | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system logs such as Active Directory Web Services  |
| win-gfx          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
| win-std          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |

### Google Cloud Platform

| VM Instance      | Login User    | Log File Path                               | Description                                                 |
| :--------------- | :------------ | :------------------------------------------ | :---------------------------------------------------------- |
| awc              | anyware_admin | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/awc-install.log           | Detailed log for AWC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/anyware-connector/configure.log    | (duplicate log from awc-install.log)                        |
| awm              | anyware_admin | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/awm-install.log           | Detailed log for Anyware Manager installation               |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/anyware-manager/install.log        | (duplicate log from awm-install.log )                       |
| centos-gfx       | anyware_admin | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | anyware_admin | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
| dc               | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system logs such as Active Directory Web Services  |
| win-gfx          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
| win-std          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\ProgramData\Teradici\PCoIPAgent\logs     | Teradici Agent logs                                         |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |

## Anyware Connector Missing
If the Anyware Connectors (AWC) do not show up in the ```Connectors``` section in Anyware Manager after Terraform deployment completed, then there is likely a problem with the provisioning script used to bring up the AWC VM. Start debugging by looking at the [logs](#vm-log-locations) via an SSH session.
- If you find errors like ```$'\r': command not found``` or ```syntax error near unexpected token `$'{\r''```, then the problem is due to Windows-style End of Line (EoL) characters in the provisioning script. The EoL character in Windows is ```\r\n``` whereas it is ```\n``` in Linux/Unix. Make sure the files checked out from the git repo on the Terraform host machine have the proper EoL.
- The Anyware Manager Deployment Service Account JSON file (specified by the ```awm_deployment_sa_file``` variable in ```terraform.tfvars```) may be incorrect. There should be errors in /var/log/teradici/provisioning.log when AWC is being installed. Make sure the file specified is correct, or create and update ```terraform.tfvars``` to use a new Deployment Service Account JSON file from Anyware Manager.
The easiest way to correct these problems is to destroy and recreate the deployment by running ```terraform destroy``` followed by ```terraform apply```.

## Failed to SSH into VMs

### Local Machine
When trying to establish an SSH session to a Linux-based VM using an SSH key, and you get and error saying ```Permission denied (publickey,gssapi-keyex,gssapi-with-mic)```, it may be becaues the VM is expecting a different SSH key. Double check the keys specified in ```terraform.tfvars``` and make sure the correct SSH key is used.
If you are using Windows and generated your key pair using PuTTYgen, you may get ```PuTTY Fatal Error``` complaining about ```No supported authentication methods available (server sent: publickey)``` with ```Server refused our key``` in PuTTY console. This happenes because PuTTYgen generates key pairs in a different format than the VM expected. Please visit [ssh-key-pair-setup](ssh-key-pair-setup.md) and follow the instructions.

### GCP Console
You have another option to SSH into your VMs if you are using GCP. Navigate to VM instances under Compute Engine of GCP Console and select the VM you are trying to connect. Click on SSH button under connect column. If it failed, then you need to check the firewall rule for that VM. Click on more actions button and select ```View network details```. Select ```FIREWALL RULES``` under Firewall and routes details and select the rule with value ```tcp:22``` in Protocols/ports column. Then click EDIT from top of the screen and make sure the IP address in Source IP ranges is the IP address you are attempting to SSH from, then save the changes. Then navigate back to VM instances page and click on SSH button under connect column of the VM you are trying to connect.
