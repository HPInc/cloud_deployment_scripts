# Troubleshooting

## Table of Contents
1. [Connecting to VMs Using SSH/RDP](#connecting-to-vms-using-ssh/rdp)
    1. [Connecting to CentOS Workstations](#connecting-to-centos-workstations)
    2. [Connecting to Windows Workstations](#connecting-to-windows-workstations)
2. [VM Log Locations](#vm-log-locations)
    1. [Amazon Web Services](#amazon-web-services)
    2. [Google Cloud Platform](#google-cloud-platform)
3. [CAS Connector Missing](#cas-connector-missing)
4. [Failed to SSH into VMs](#failed-to-ssh-into-vms)
    1. [Local Machine](#local-machine)
    2. [GCP Console](#gcp-console)

---

## Connecting to VMs Using SSH/RDP
- To debug Linux VMs, SSH can be used to login to the machines for troubleshooting and viewing log files. 
- To debug Windows VMs, a RDP client such as Windows Remote Desktop on Windows or xfreerdp on Linux can be used to login to the machines for troubleshooting and viewing log files.
- Workstation VMs are not exposed to the internet and do not have public IPs, a bastion host such as the DC or Connector can be used to access the Workstation VMs on the private network.

### Connecting to CentOS Workstations
- One way to access CentOS Workstations is to use the Connector as a bastion host. Please refer to the log tables below for the corresponding <login-user> for each VM.
- Use the -i flag to provide SSH with the private key that pairs with the public keys specified in terraform.tfvars.
- For GCP, enter the private key path that pairs with cac_admin_ssh_pub_key_file for the Connector or centos_admin_ssh_pub_key_file for CentOS Workstations.
- For AWS, enter the private key path that pairs with admin_ssh_pub_key_file for the Connector and CentOS Workstations.

Execute the following command to first SSH into the Connector:

```ssh -A -i </path/to/ssh-private-key> <login-user>@<cac-public-ip>``` 

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
| cac              | ubuntu        | /var/log/syslog                             | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/user-data.log             | Detailed output of user-data script                         |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
| cas-mgr          | rocky         | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/cas-mgr-install.log       | Detailed log for CAS Manager installation                   |
|                  |               | /var/log/cas-mgr/install.log                | (duplicate log from cas-mgr-install.log )                   |
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
| cac              | cas_admin     | /var/log/syslog                             | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
| cas-mgr          | cas_admin     | /var/log/messages                           | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/teradici/cas-mgr-install.log       | Detailed log for CAS Manager installation                   |
|                  |               | /var/log/cloud-init-output.log              | Console output log from cloud-init                          |
|                  |               | /var/log/cas-mgr/install.log                | (duplicate log from cas-mgr-install.log )                   |
| centos-gfx       | cas_admin     | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | cas_admin     | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
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

## CAS Connector Missing
If the CAS Connectors (cac) do not show up in the ```Connectors``` section in CAS Manager after Terraform deployment completed, then there is likely a problem with the provisioning script used to bring up the cac VM. Start debugging by looking at the [logs](#vm-log-locations) via an SSH session.
- If you find errors like ```$'\r': command not found``` or ```syntax error near unexpected token `$'{\r''```, then the problem is due to Windows-style End of Line (EoL) characters in the provisioning script. The EoL character in Windows is ```\r\n``` whereas it is ```\n``` in Linux/Unix. Make sure the files checked out from the git repo on the Terraform host machine have the proper EoL. 
- The CAS Manager Deployment Service Account JSON file (specified by the ```cas_mgr_deployment_sa_file``` variable in ```terraform.tfvars```) may be incorrect. There should be errors in /var/log/teradici/provisioning.log when CAC is being installed. Make sure the file specified is correct, or create and update ```terraform.tfvars``` to use a new Deployment Service Account JSON file from CAS Manager.
The easiest way to correct these problems is to destroy and recreate the deployment by running ```terraform destroy``` followed by ```terraform apply```.

## Failed to SSH into VMs
 
### Local Machine
When trying to establish an SSH session to a Linux-based VM using an SSH key, and you get and error saying ```Permission denied (publickey,gssapi-keyex,gssapi-with-mic)```, it may be becaues the VM is expecting a different SSH key. Double check the keys specified in ```terraform.tfvars``` and make sure the correct SSH key is used.
If you are using Windows and generated your key pair using PuTTYgen, you may get ```PuTTY Fatal Error``` complaining about ```No supported authentication methods available (server sent: publickey)``` with ```Server refused our key``` in PuTTY console. This happenes because PuTTYgen generates key pairs in a different format than the VM expected. Please visit [ssh-key-pair-setup](ssh-key-pair-setup.md) and follow the instructions.

### GCP Console
You have another option to SSH into your VMs if you are using GCP. Navigate to VM instances under Compute Engine of GCP Console and select the VM you are trying to connect. Click on SSH button under connect column. If it failed, then you need to check the firewall rule for that VM. Click on more actions button and select ```View network details```. Select ```FIREWALL RULES``` under Firewall and routes details and select the rule with value ```tcp:22``` in Protocols/ports column. Then click EDIT from top of the screen and make sure the IP address in Source IP ranges is the IP address you are attempting to SSH from, then save the changes. Then navigate back to VM instances page and click on SSH button under connect column of the VM you are trying to connect. 
