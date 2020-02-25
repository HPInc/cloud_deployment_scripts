#!/usr/bin/python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import json
import os
from google.cloud  import kms_v1
from google.oauth2 import service_account

GCP_CREDENTIALS_FILE = None
CAM_CREDENTIALS_FILE = None


# Create KMS key ring
def create_key_ring(client, project_id, location, key_ring_id):
    parent = client.location_path(project_id, location)

    # The key ring object template
    keyring_path = client.key_ring_path(project_id, location, key_ring_id)
    keyring      = {"name": keyring_path}

    # Create a key ring
    response = client.create_key_ring(parent, key_ring_id, keyring)

    return response.name


def create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id):
    parent = client.key_ring_path(project_id, location, key_ring_id)

    # Create the crypto key object template
    purpose    = kms_v1.enums.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT
    crypto_key = { "purpose": purpose }

    # Create a crypto key for the given key ring
    response = client.create_crypto_key(parent, crypto_key_id, crypto_key)

    return response.name

"""
# Decrypt CAM JSON credentials file
def decrypt_cam_credentials(client, kms_cryptokey_id):
    # CAM credentials file path to be decrypted
    cam_credentials_file = CAM_CREDENTIALS_FILE

    # Decrypt CAM JSON credentials
    try:
        print("Decrypting CAM credentials...")
        cam_credentials_ciphertext = ""

        with open(cam_credentials_file) as f:
            cam_credentials_ciphertext = f.read()
    
        cam_credentials_decrypted = decrypt_ciphertext(client, kms_cryptokey_id, cam_credentials_ciphertext)
        
        print("Finished decrypting CAM credentials.\n")

        with open("{}".format(cam_credentials_file.replace(".encrypted", "")), "w") as cam_credentials_decrypted_file:
            cam_credentials_decrypted_file.write(cam_credentials_decrypted)

        os.remove(cam_credentials_file)

    except Exception as err:
        print("An exception occurred decrypting CAM JSON credentials:")
        print("{}\n".format(err))
        raise SystemExit()


# Decrypt ciphertext using the provided symmetric crypto key
def decrypt_ciphertext(client, kms_cryptokey_id, ciphertext):
    # Resource name of the crypto key
    crypto_key_path = kms_cryptokey_id

    # Convert ciphertext string to a byte string
    ciphertext = ciphertext.encode("utf-8")

    # Base64 decoding of ciphertext
    ciphertext = base64.b64decode(ciphertext)

    # Use the KMS API to decrypt the data.
    response = client.decrypt(crypto_key_path, ciphertext)

    # Decode Base64 plaintext
    plaintext = response.plaintext.decode()
    return plaintext


def decrypt_tfvars_secrets(tfvars_path):    
    # Read tfvars file into a dictionary
    tfvars_dict = read_terraform_tfvars(tfvars_path)

    # Abort the decryption if the tfvars is already encrypted
    if not tfvars_dict.get("kms_cryptokey_id"):
        print("Did not find kms_cryptokey_id in tfvars. Ensure that the secrets are encrypted and try again.\n")
        raise SystemExit()

    # Get the ciphertext secrets to be decrypted inside the tfvars file
    secrets = get_tfvars_secrets(tfvars_dict, tfvars_path)

    # Set GCP credentials global variable for the client
    global GCP_CREDENTIALS_FILE
    GCP_CREDENTIALS_FILE = tfvars_dict.get("gcp_credentials_file")

    # Create an API client for the KMS API using the provided GCP service account
    credentials = service_account.Credentials.from_service_account_file(GCP_CREDENTIALS_FILE)
    client      = kms_v1.KeyManagementServiceClient(credentials = credentials)

    # GCP KMS resource variables
    kms_cryptokey_id   = tfvars_dict.get("kms_cryptokey_id")

    # Decrypt secrets including CAM credentials
    print("Decrypting using cryptokey:\n{}\n".format(kms_cryptokey_id))

    try:
        for secret in secrets:
            print("Decrypting {}...".format(secret))
            plaintext = decrypt_ciphertext(client, kms_cryptokey_id, secrets.get(secret))
            print("Finished decrypting {0}.\n".format(secret))
            secrets[secret] = plaintext

        if tfvars_dict.get("cam_credentials_file"):
            decrypt_cam_credentials(client, kms_cryptokey_id)
            
    except Exception as err:
        print("An exception occurred decrypting secrets:")
        print("{}\n".format(err))
        raise SystemExit()

    # Overwrite existing terraform.tfvars file with plaintext secrets
    write_new_tfvars(tfvars_path, secrets, kms_cryptokey_id)
"""

# Encrypt CAM JSON credential file
def encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id, secrets):
    cam_credentials_file = CAM_CREDENTIALS_FILE

    # Encrypt CAM JSON credentials
    try:
        print("Encrypting CAM credentials...\n")
        
        with open(cam_credentials_file) as cam_credentials:
            cam_credentials = json.load(cam_credentials)
    
        cam_credentials_string = json.dumps(cam_credentials)
        cam_credentials_encrypted_string = encrypt_plaintext(client, project_id, location, key_ring_id, 
                                                             crypto_key_id, cam_credentials_string)
        
        print("Finished encrypting CAM credentials.\n")

        cam_credentials_file_encrypted = "{}.encrypted".format(cam_credentials_file)
        
        with open(cam_credentials_file_encrypted, "w") as f:
            f.write(cam_credentials_encrypted_string)
        
        # Add .backup postfix to the original and change the global variable to the encrypted file
        os.rename(cam_credentials_file, "{}.backup".format(cam_credentials_file))

    except Exception as err:
        print("An exception occurred encrypting CAM JSON credentials:")
        print("{}\n".format(err))
        raise SystemExit()
    
    return cam_credentials_file_encrypted


# Encrypt plaintext data using the provided symmetric crypto key
def encrypt_plaintext(client, project_id, location, key_ring_id, crypto_key_id,
                      plaintext):
    # Resource path of the crypto key
    crypto_key_path = client.crypto_key_path_path(project_id, location, key_ring_id, 
                        crypto_key_id)

    # UTF-8 encoding of plaintext
    plaintext = plaintext.encode("utf-8")

    # Use the KMS API to encrypt the data.
    response = client.encrypt(crypto_key_path, plaintext)

    # Base64 encoding of ciphertext
    ciphertext = base64.b64encode(response.ciphertext).decode()
    
    return ciphertext


def encrypt_tfvars_secrets(tfvars_path):    
    # Read tfvars data and secrets into dictionaries
    tfvars_data = read_tfvars_data(tfvars_path)
    secrets     = read_tfvars_secrets(tfvars_path)
    
    # Abort the encryption if the tfvars is already encrypted with a kms_cryptokey_id present
    if tfvars_data.get("kms_cryptokey_id"):
        print("Detected kms_cryptokey_id in tfvars. Ensure that the secrets are not already encrypted and try again.\n")
        raise SystemExit()

    # Set GCP and CAM credentials global variables from tfvars
    global GCP_CREDENTIALS_FILE
    global CAM_CREDENTIALS_FILE
    GCP_CREDENTIALS_FILE = tfvars_data.get("gcp_credentials_file")
    CAM_CREDENTIALS_FILE = secrets.get("cam_credentials_file")

    # Create an API client for the KMS API using the provided GCP service account
    credentials = service_account.Credentials.from_service_account_file(GCP_CREDENTIALS_FILE)
    client      = kms_v1.KeyManagementServiceClient(credentials = credentials)

    # GCP KMS resource variables
    project_id = tfvars_data.get("gcp_project_id")
    location   = "global"

    key_rings_list   = get_key_rings(client, project_id, location)
    crypto_keys_list = get_crypto_keys(client, project_id, location, key_rings_list)

    key_ring_id = "terraform-keyring"
    crypto_key_id = "terraform-cryptokey"

    # Create the key ring only if it doesn't exist
    if key_ring_id not in key_rings_list:
        try:
            key_ring_id = create_key_ring(client, project_id, location, key_ring_id)
            print("Created key ring: {}\n".format(kms_keyring_id))
    
        except Exception as err:
            print("An exception occurred creating new key ring:")
            print("{}".format(err))
            raise SystemExit()
    
    # Create a crypto key only if it doesn't exist
    if crypto_key_id not in crypto_keys_list:
        try:
            crypto_key_id = create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id)
            print("kms_cryptokey_id: {}\n".format(kms_cryptokey_id))

        except Exception as err:
            print("An exception occurred creating new crypto key:")
            print("{}".format(err))
            raise SystemExit()
    
    # Encrypt all secrets found in the secrets dictionary
    try:
        for secret in secrets:
            print("Encrypting {}...\n".format(secret))

            # Additional handling needed if the string is a path to a file (IE. cam_credentials_file)
            if secret == "cam_credentials_file":
                cam_credentials_file_encrypted = encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id, secrets)
                secrets["cam_credentials_file"] = cam_credentials_file_encrypted
            else:
                ciphertext = encrypt_plaintext(client, project_id, location, key_ring_id, crypto_key_id, secrets.get(secret))
                secrets[secret] = ciphertext
        

    except Exception as err:
        print("An exception occurred encrypting secrets:")
        print("{}\n".format(err))
        raise SystemExit()
    
    # Write secrets into new terraform.tfvars file
    kms_cryptokey_id = client.crypto_key_path_path(project_id, location, key_ring_id, crypto_key_id)
    write_new_tfvars(tfvars_path, secrets, kms_cryptokey_id)


# Get KMS key rings
def get_key_rings(client, project_id, location):
    parent   = client.location_path(project_id, location)
    response = client.list_key_rings(parent)
    
    # Extract just the key ring name from each response and put into a list
    key_rings_list = list(map(lambda key_ring: key_ring.name.rpartition('/')[2], response))

    return key_rings_list


# Get KMS crypto keys
def get_crypto_keys(client, project_id, location, key_rings_list):
    crypto_keys_list = []

    for key_ring in key_rings_list:
        parent   = client.key_ring_path(project_id, location, key_ring)
        response = client.list_crypto_keys(parent)

        # Extract just the crypto key name from each response and put that into a temp list
        temp_list = list(map(lambda key: key.name.rsplit('/', 1)[1], response))

        for crypto_key in temp_list:
            crypto_keys_list.append(crypto_key)

    return crypto_keys_list


# Read terraform.tfvars for user provided configurations
def read_tfvars_data(tfvars_file):
    tf_data = {}

    with open(tfvars_file, 'r') as f:
        for line in f:
            if "# Secrets below can be encrypted using GCP-KMS, refer to the README for more information." in line:
                break

            if line[0] in ('#', '\n'):
                continue
        
            # Split using the first delimiter
            key, value = map(str.strip, line.split('=', 1))
            tf_data[key] = value.replace("\"", "")
            
    return tf_data


# Read terraform.tfvars for user provided secrets
def read_tfvars_secrets(tfvars_file):
    tf_secrets = {}
    begin_reading_secrets = False

    with open(tfvars_file, 'r') as f:
        for line in f:
            if "# Secrets below can be encrypted using GCP-KMS, refer to the README for more information." in line:
                begin_reading_secrets = True
                continue
            
            if line[0] in ('#', '\n'):
                continue

            if begin_reading_secrets:
                # Split using the first delimiter
                key, value = map(str.strip, line.split('=', 1))
                tf_secrets[key] = value.replace("\"", "")
            
    return tf_secrets


# Write the new tfvars file using encrypted secrets
def write_new_tfvars(tfvars_file, secrets, kms_cryptokey_id):
    cam_credentials_file = CAM_CREDENTIALS_FILE

    # Resource format "projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>"
    kms_resource_list  = kms_cryptokey_id.split('/')

    # Key ring name is at index 5 and crypto key name is at index 7
    kms_keyring_name   = kms_resource_list[5]
    kms_cryptokey_name = kms_resource_list[7]

    lines = []
    
    with open(tfvars_file, 'r') as f:

        for line in f:
            lines.append(line.rstrip())

            if "# Secrets below can be encrypted using GCP-KMS, refer to the README for more information." in line:
                break
        
        lines.append("{} = \"{}\"".format("kms_cryptokey_id", kms_cryptokey_id))

        for key, value in secrets.items():
            lines.append("{} = \"{}\"".format(key, value))

    # Add .backup postfix to the original tfvars file
    os.rename(tfvars_file, "{}.backup".format(tfvars_file))

    # Rewrite the existing terraform.tfvars
    with open(tfvars_file, 'w') as f:
        f.writelines("%s\n" %line for line in lines)


# Use argparse to determine user's specified terraform.tfvars and provide -d flag for decryption instead
def main():
    parser_description = ("Creates GCP KMS keyring and key, and uses the key to encrypt or decrypt secrets in the specified terraform.tfvars."
                          "The script encrypts by default. To decrypt instead, use the -d flag.")

    parser = argparse.ArgumentParser(description=parser_description)

    parser.add_argument("tfvars", help="specify the path to terraform.tfvars file")
    parser.add_argument("-d", help="decrypt secrets in terraform.tfvars specified", action='store_true')

    args = parser.parse_args()
    
    if args.d:
        print("Decrypting secrets...\n")
        decrypt_tfvars_secrets(args.tfvars)
    else:
        print("Encrypting secrets...\n")
        encrypt_tfvars_secrets(args.tfvars)


if __name__ == '__main__':
    main()

