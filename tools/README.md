# generate_names.py
This is a Python 3 script that generates a bulk user CSV to be used with ../modules/gcp/dc/new_domain_users.ps1.tpl.

The CSV file generated will have random First name, Last name and password.  The username will be [first initial]+[last name].

To run:
```
python3 -m venv env
. env/bin/activate
pip install names
python3 generate_names.py 99 > domain_users_list.csv
deactivate
```

# kms_secrets_encryption.py
This is a Python 3 script that automates the encryption and decryption of secrets in a terraform.tfvars file
so that it is ready to be used for Terraform deployments with KMS-encrypted secrets. This script supports
both AWS and GCP terraform.tfvars as it detects the platform used based on the credentials file provided
in the terraform.tfvars file.

All secrets below the line "# <-- Start of secrets section, do not edit this line. -->" will be encrypted by this script.

If the secret is a path to a text file, it will encrypt the file.

AWS: The script is defaulted to use "cas_key" to encrypt your secrets. Ensure that the "customer_master_key_id"
line in terraform.tfvars is commented out.

GCP: The script is defaulted to use "cas-keyring" and "cas_key" to encrypt your secrets. Ensure that the "kms_cryptokey_id" 
line in terraform.tfvars is commented out.

To encrypt:
```
./kms_secrets_encryption.py <path/to/terraform.tfvars>
```

To decrypt:
```
./kms_secrets_encryption.py -d <path/to/terraform.tfvars>
```
