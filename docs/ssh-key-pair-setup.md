# SSH Key Pair Setup

## Table of Contents
1. [Creating a SSH key pair on Windows machines](#creating-a-ssh-key-pair-on-windows-machines)
2. [Creating a SSH key pair on Linux machines](#creating-a-ssh-key-pair-on-linux-machines)

## Creating a SSH key pair on Windows machines
1. Download PuTTYgen from https://www.puttygen.com/download-putty.
2. Create a key pair by clicking "Generate" with "RSA" selected.
3. Save the public key. PuTTYgen will prompt for a directory and file name to save in. 
The file path of the public key will be used when customizing terraform.tfvars.
4. Save the private key. PuTTYgen will prompt for a directory and file name to save in. 
This file is in PuTTY's native format (*.PPK) and will be the key required for SSH authentication using PuTTY.

For more details:
- Please refer to https://www.ssh.com/ssh/putty/windows/puttygen for instructions to create SSH keys.

## Creating a SSH key pair on Linux machines
1. Create a key pair using the following command in terminal:

```ssh-keygen -t rsa```

2. Enter file in which to save the key (home/user/.ssh/id_rsa), press enter to save in the default location.
3. Enter passphrase (empty for no passphrase) or press enter for no passphrase.
4. Enter same passphrase again, press enter to confirm.
5. Save the path of the public key outputted to the terminal as this path will be used when customizing terraform.tfvars.
