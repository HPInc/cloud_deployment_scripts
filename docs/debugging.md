# Debugging

## Connecting to VMs Using SSH/RDP
- To debug Linux VMs, SSH can be used to login to the machines for troubleshooting and viewing log files. 
- To debug Windows VMs, a RDP client such as Windows Remote Desktop on Windows or xfreerdp on Linux can be used to login to the machines for troubleshooting and viewing log files.
- Workstation VMs are not exposed to the internet and do not have public IPs, a bastion host such as the DC or Connector can be used to access the Workstation VMs on the private network.

### Connecting to CentOS Workstations
One way to access CentOS Workstations is to use the Connector as a bastion host. Execute the following command to first SSH into the Connector:

```ssh -A <login-user>@<cac-public-ip>``` 

From inside the Connector, execute the following command to SSH into the CentOS Workstation:

```ssh <login-user>@<centos-internal-ip>```

### Connecting to Windows Workstations
One way to access Windows Workstations is to use the Domain Controller as a bastion host. Use the following credentials to connect to the DC using a RDP client:

```
Computer: <domain-controller-public-ip>
User: <login-user>
Password: <dc_admin_password>
```

From inside the Domain Controller, connect to the Windows Workstation by using Windows RDP and entering the following login credentials:

```
Computer: <win-internal-ip>
User: <login-user>
Password: <dc_admin_password>
```

## VM Log Locations

### Amazon Web Services

| VM Instance      | Login User    | Log File Path                               | Description                                                 |
| :--------------- | :------------ | :------------------------------------------ | :---------------------------------------------------------- |
| cac              | ubuntu        | /var/log/syslog                             | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for provisioning script                         |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log (duplicate log from provisioning.log)    |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
| centos-gfx       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for Bash provisioning script                    |
|                  |               | /var/log/user-data.log                      | Detailed output of provisioning script (duplicate log)      |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for Bash provisioning script                    |
|                  |               | /var/log/user-data.log                      | Detailed output of provisioning script (duplicate log)      |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
| lls              | centos        | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for Bash provisioning script                    |
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
| cac              | cam_admin     | /var/log/syslog                             | Detailed system log for startup and provisioning            |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for provisioning script                         |
|                  |               | /var/log/teradici/cac-install.log           | Detailed log for CAC installation                           |
|                  |               | /var/log/cloud-init-output.log              | Console output log (duplicate log from provisioning.log)    |
|                  |               | /var/log/cloud-access-connector/install.log | (duplicate log from cac-install.log)                        |
| centos-gfx       | cam_admin     | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for Bash provisioning script                    |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
|                  |               | /var/log/nvidia-installer.log               | Detailed log for NVIDIA driver installation                 |
| centos-std       | cam_admin     | /var/log/messages.log                       | Combined detailed system log for startup and provisioning   |
|                  |               | /var/log/teradici/provisioning.log          | Minimal log for Bash provisioning script                    |
|                  |               | /var/log/yum.log                            | Yum log file (duplicate log from messages.log)              |
|                  |               | /var/log/pcoip-agent/agent.log              | PCoIP agent log file                                        |
| dc               | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system logs such as Active Directory Web Services  |
| win-gfx          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
| win-std          | Administrator | C:\Teradici\provisioning.log                | Detailed transcript log for PowerShell provisioning script  |
|                  |               | C:\Windows\System32\winevt\Logs             | Detailed system and event logs                              |
