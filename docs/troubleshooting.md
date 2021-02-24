# Troubleshooting

## Table of Contents
1. [Connecting to VMs Using SSH/RDP](#connecting-to-vms-using-ssh/rdp)
    1. [Connecting to CentOS Workstations](#connecting-to-centos-workstations)
    2. [Connecting to Windows Workstations](#connecting-to-windows-workstations)
2. [VM Log Locations](#vm-log-locations)
    1. [Amazon Web Services](#amazon-web-services)
    2. [Google Cloud Platform](#google-cloud-platform)

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
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log (duplicate log from provisioning.log)    |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
| centos-gfx       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/user-data.log                      | Detailed output of provisioning script (duplicate log)      |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/user-data.log                      | Detailed output of provisioning script (duplicate log)      |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
| lls              | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for Bash provisioning script                   |
|                  |               | /var/log/user-data.log                      | Detailed output of provisioning script (duplicate log)      |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
| dc               | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system logs such as Active Directory Web Services  |
| win-gfx          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
| win-std          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |

### Google Cloud Platform

| VM Instance      | Login User    | Log File Path                               | Description                                                 |
| :--------------- | :------------ | :------------------------------------------ | :---------------------------------------------------------- |
| cac              | cas_admin     | /var/log/syslog                             | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Detailed log for provisioning script                        |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log (duplicate log from provisioning.log)    |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
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
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system logs such as Active Directory Web Services  |
| win-gfx          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
| win-std          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
