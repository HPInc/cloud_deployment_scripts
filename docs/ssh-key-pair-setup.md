# SSH Key Pair Setup

## Table of Contents
1. [Creating a SSH key pair on Windows machines](#creating-a-ssh-key-pair-on-windows-machines)
2. [Creating a SSH key pair on Linux machines](#creating-a-ssh-key-pair-on-linux-machines)

## Creating a SSH key pair on Windows machines
1. Download PuTTYgen from https://www.puttygen.com/download-putty.
2. Create a key pair by clicking "Generate" with "RSA" selected.
3. Execute the following command in PowerShell to convert the SSH2 public key created from PuTTYgen to the required OpenSSH format:

```ssh-keygen -i -f C:\path\to\ssh2-original-key.pub > C:\path\to\openssh-converted-key.pub```

4. Save the path of the public key after conversion as this path will be used when customizing terraform.tfvars

For more details:
- Please refer to https://www.ssh.com/ssh/putty/windows/puttygen for instructions to create SSH keys. 
- Please refer to https://tutorialinux.com/convert-ssh2-openssh/ for detailed instructions on converting the key to OpenSSH format.

## Creating a SSH key pair on Linux machines
1. Create a key pair using the following command in terminal:

```ssh-keygen -t rsa```

2. Enter file in which to save the key (home/user/.ssh/id_rsa), press enter to save in the default location.
3. Enter passphrase (empty for no passphrase) or press enter for no passphrase.
4. Enter same passphrase again, press enter to confirm.
5. Save the path of the public key outputted to the terminal as this path will be used when customizing terraform.tfvars
