# SSH Key Pair Setup

## Creating a SSH key pair on Windows machines
- Create a key pair using PuTTYgen. Please refer to https://www.ssh.com/ssh/putty/windows/puttygen for instructions to create SSH keys. 
- Once the public / private key pair is created, the SSH2 public key format must be converted to a OpenSSH format for Terraform. Please refer to https://tutorialinux.com/convert-ssh2-openssh/ for detailed instructions. 
- Execute the following command in PowerShell to convert the SSH2 public key created from PuTTYgen to the required OpenSSH format:

```ssh-keygen -i -f C:\path\to\ssh2-original-key.pub > C:\path\to\openssh-converted-key.pub```

## Creating a SSH key pair on Linux machines
- Create a key pair using the following command in terminal:

```ssh-keygen -t rsa```

- Enter file in which to save the key (home/user/.ssh/id_rsa), press enter to save in the default location.
- Enter passphrase (empty for no passphrase), press enter for no passphrase.
- Enter same passphrase again, press enter to confirm.
- Save the path of the public key outputted to the terminal as this path will be used when customizing terraform.tfvars
