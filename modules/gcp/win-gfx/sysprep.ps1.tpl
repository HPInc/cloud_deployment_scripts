net user Administrator "${admin_password}" /active:yes
Enable-PSRemoting -Force
winrm set winrm/config/service/auth '@{Basic="true"}'