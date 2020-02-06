#!/usr/bin/python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import json
import os
from google.cloud        import kms_v1
from google.cloud.kms_v1 import enums
from google.oauth2       import service_account
from urllib.error        import HTTPError

# Global variables
GCP_CREDENTIALS_FILE = None
CAM_CREDENTIALS_FILE = None

# Create crypto key within a key ring
def create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id):
    parent = client.key_ring_path(project_id, location, key_ring_id)

    # Create the crypto key object template
    purpose    = enums.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT
    crypto_key = { "purpose": purpose }

    # Create a crypto key for the given key ring
    response = client.create_crypto_key(parent, crypto_key_id, crypto_key)

    return response.name

    
# Create KMS key ring
def create_key_ring(client, project_id, location, key_ring_id):
    parent = client.location_path(project_id, location)

    # The key ring object template
    keyring_path = client.key_ring_path(project_id, location, key_ring_id)
    keyring      = {"name": keyring_path}

    # Create a key ring
    response = client.create_key_ring(parent, key_ring_id, keyring)

    return response.name


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


# Decrypt ciphertext using the provided symmetric crypto key
def decrypt_ciphertext(client, kms_cryptokey_id, ciphertext):
    # Resource name of the crypto key
    crypto_key_path = kms_cryptokey_id

    # UTF-8 encoding of ciphertext
    ciphertext = ciphertext.encode("utf-8")

    # Base64 decoding of ciphertext
    ciphertext = base64.b64decode(ciphertext)

    # Use the KMS API to decrypt the data.
    response = client.decrypt(crypto_key_path, ciphertext)

    # Decode Base64 plaintext
    plaintext = response.plaintext.decode()
    return plaintext


def decrypt_tfvars_secrets():
    # Path to the tfvars file depends on user input (single, multi, or dc-only)
    tfvars_path = get_tfvars_path()
    
    # Read tfvars file into a dictionary
    tfvars_dict = read_terraform_tfvars(tfvars_path)

    # Abort the encryption if the tfvars is already encrypted
    if not tfvars_dict.get("kms_cryptokey_id"):
        print("Did not find kms_cryptokey_id in tfvars. Ensure that the secrets are encrypted and try again.\n")
        raise SystemExit()

    # Get the ciphertext secrets to be decrypted inside the tfvars file
    secrets = get_tfvars_secrets(tfvars_dict, tfvars_path)

    # Set GCP credentials global variable for the client
    global GCP_CREDENTIALS_FILE
    GCP_CREDENTIALS_FILE = tfvars_dict.get("gcp_credentials_file").replace('\"', '')

    # Create an API client for the KMS API using the provided GCP service account
    credentials = service_account.Credentials.from_service_account_file(GCP_CREDENTIALS_FILE)
    client      = kms_v1.KeyManagementServiceClient(credentials = credentials)

    # GCP KMS resource variables
    kms_cryptokey_id   = tfvars_dict.get("kms_cryptokey_id").replace('\"', '')

    # Decrypt secrets including CAM credentials
    print("Decrypting using cryptokey:\n{}\n".format(kms_cryptokey_id))

    try:
        for secret in secrets:
            print("Decrypting {}...".format(secret))
            plaintext = decrypt_ciphertext(client, kms_cryptokey_id, secrets.get(secret))
            print("Finished decrypting {0}.\n".format(secret))
            secrets[secret] = plaintext.replace('\"', '')

        if tfvars_dict.get("cam_credentials_file"):
            decrypt_cam_credentials(client, kms_cryptokey_id)
            
    except Exception as err:
        print("An exception occurred decrypting secrets:")
        print("{}\n".format(err))

    # Overwrite existing terraform.tfvars file with plaintext secrets
    write_new_tfvars(tfvars_path, secrets, kms_cryptokey_id)


# Encrypt CAM JSON credential file
def encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id):
    # CAM credentials file path to be encrypted
    cam_credentials_file = CAM_CREDENTIALS_FILE

    # Encrypt CAM JSON credentials
    try:
        print("Encrypting CAM credentials...\n")
        
        with open(cam_credentials_file) as cam_credentials:
            cam_credentials = json.load(cam_credentials)
    
        cam_credentials_string = json.dumps(cam_credentials)
        cam_credentials_encrypted = encrypt_plaintext(client, project_id, location, key_ring_id, 
                                    crypto_key_id, cam_credentials_string)
        
        print("Finished encrypting CAM credentials:\n{}\n".format(cam_credentials_encrypted))

        with open("{}.encrypted".format(cam_credentials_file), "w") as cam_credentials_encrypted_file:
            cam_credentials_encrypted_file.write(cam_credentials_encrypted)

        os.remove(cam_credentials_file)

    except Exception as err:
        print("An exception occurred encrypting CAM JSON credentials:")
        print("{}\n".format(err))


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


def encrypt_tfvars_secrets():
    # Path to the tfvars file depends on user input (single, multi, or dc-only)
    tfvars_path = get_tfvars_path()
    
    # Read tfvars file into a dictionary
    tfvars_dict = read_terraform_tfvars(tfvars_path)

    # Abort the encryption if the tfvars is already encrypted
    if tfvars_dict.get("kms_cryptokey_id"):
        print("Detected kms_cryptokey_id in tfvars. Ensure that the secrets are not already encrypted and try again.\n")
        raise SystemExit()

    # Get the secrets to be encrypted inside the tfvars file
    secrets = get_tfvars_secrets(tfvars_dict, tfvars_path)

    # Set GCP credentials global variable for the client
    global GCP_CREDENTIALS_FILE
    GCP_CREDENTIALS_FILE = tfvars_dict.get("gcp_credentials_file").replace('\"', '')

    # Create an API client for the KMS API using the provided GCP service account
    credentials = service_account.Credentials.from_service_account_file(GCP_CREDENTIALS_FILE)
    client      = kms_v1.KeyManagementServiceClient(credentials = credentials)

    # GCP KMS resource variables
    project_id = tfvars_dict.get("gcp_project_id").replace('\"', '')
    location   = "global"

    if tfvars_dict.get("kms_keyring_name")   == None or \
       tfvars_dict.get("kms_cryptokey_name") == None:
        key_ring_id   = "terraform-keyring"
        crypto_key_id = "terraform-cryptokey"
    else:
        key_ring_id   = tfvars_dict.get("kms_keyring_name").replace('\"', '')
        crypto_key_id = tfvars_dict.get("kms_cryptokey_name").replace('\"', '')

    # List all key rings
    list_key_rings(client, project_id, location)

    # Create the key ring
    try:
        kms_keyring_id = create_key_ring(client, project_id, location, key_ring_id)
        print("Created key ring: {}\n".format(kms_keyring_id))
    
    except Exception as err:
        print("An exception occurred creating new key ring:")
        print("{}".format(err))
        print("Using existing key ring: {}\n".format(key_ring_id))

    # Create a crypto key
    try:
        kms_cryptokey_id = create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id)
        print("kms_cryptokey_id: {}\n".format(kms_cryptokey_id))

    except Exception as err:
        print("An exception occurred creating new crypto key:")
        print("{}".format(err))
        print("Using existing crypto key: {}\n".format(crypto_key_id))

    # Encrypt secrets including CAM credentials
    try:
        for secret in secrets:
            print("Encrypting {}...\n".format(secret))
            ciphertext = encrypt_plaintext(client, project_id, location, key_ring_id, crypto_key_id, secrets.get(secret))
            print("Finished encrypting {0}:\n{1}\n".format(secret, ciphertext))
            secrets[secret] = ciphertext

        if tfvars_dict.get("cam_credentials_file"):
            encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id)
            
    except Exception as err:
        print("An exception occurred encrypting secrets:")
        print("{}\n".format(err))

    # Write secrets into new terraform.tfvars file
    kms_cryptokey_id = client.crypto_key_path_path(project_id, location, key_ring_id, crypto_key_id)
    write_new_tfvars(tfvars_path, secrets, kms_cryptokey_id)


# Prompt user for deployment type (multi-region or single) and returns the path to the tfvars
def get_tfvars_path():
    validInput = False
    deployment = None

    while not validInput:
        deployment = input("Enter 0, 1, or 2 for the deployment type:\n"
                           "[0] for single-connector\n"
                           "[1] for multi-region\n"
                           "[2] for dc-only\n")
        
        if deployment == "0" or deployment == "1" or deployment == "2":
            validInput = True

    # Read the corresponding .tfvars file based on user selection
    switcher = {
        "0": "../deployments/gcp/single-connector/terraform.tfvars",
        "1": "../deployments/gcp/multi-region/terraform.tfvars",
        "2": "../deployments/gcp/dc-only/terraform.tfvars"
    }

    return switcher.get(deployment)


# Collect the required secrets for the appropriate deployment from the tfvars file
def get_tfvars_secrets(tfvars_dict, tfvars_path):
    secrets = {
        "dc_admin_password"           : tfvars_dict.get("dc_admin_password"),
        "safe_mode_admin_password"    : tfvars_dict.get("safe_mode_admin_password"),
        "ad_service_account_password" : tfvars_dict.get("ad_service_account_password")
    }
    
    if "single-connector" in tfvars_path or "multi-region" in tfvars_path:
        secrets.update(pcoip_registration_code = tfvars_dict.get("pcoip_registration_code"))

        global CAM_CREDENTIALS_FILE
        CAM_CREDENTIALS_FILE = tfvars_dict.get("cam_credentials_file").replace('\"', '')

    return secrets


# List KMS key rings
def list_key_rings(client, project_id, location):
    parent        = client.location_path(project_id, location)
    response      = client.list_key_rings(parent)
    response_list = list(response)

    if len(response_list) > 0:
        print("Key rings in project:")
        for key_ring in response_list:
            print("{}\n".format(key_ring.name))
    else:
        print("No key rings found.\n")


# Read terraform.tfvars for user provided configurations
def read_terraform_tfvars(tfvars_file):
    tf_data = {}

    with open(tfvars_file, 'r') as f:
        for line in f:
            if line[0] in ('#', '\n'):
                continue
            
            # Split using the first delimiter
            key, value = map(str.strip, line.split('=', 1))
            tf_data[key] = value

    return tf_data


# Write the new tfvars file using encrypted secrets
def write_new_tfvars(tfvars_file, secrets, kms_cryptokey_id):
    kms_resource_list  = kms_cryptokey_id.split('/')
    kms_keyring_name   = kms_resource_list[5]
    kms_cryptokey_name = kms_resource_list[7]

    lines = []
    
    with open(tfvars_file, 'r') as f:
        for line in f:
            if "dc_admin_password" in line:
                line = "dc_admin_password           = \"{}\"".format(secrets.get("dc_admin_password"))

            if "safe_mode_admin_password" in line:
                line = "safe_mode_admin_password    = \"{}\"".format(secrets.get("safe_mode_admin_password"))

            if "ad_service_account_password" in line:
                line = "ad_service_account_password = \"{}\"".format(secrets.get("ad_service_account_password"))

            if "pcoip_registration_code" in line:
                line = "pcoip_registration_code     = \"{}\"".format(secrets.get("pcoip_registration_code"))    

            # Writes the correct cam_credentials_file path depending on if it is encrypted or plaintext JSON
            if "cam_credentials_file" in line:
                if ".encrypted" in line:
                    line = "cam_credentials_file        = \"{}\"".format(CAM_CREDENTIALS_FILE.replace(".encrypted", ""))
                else:
                    line = "cam_credentials_file        = \"{}.encrypted\"".format(CAM_CREDENTIALS_FILE)

            if "kms_cryptokey_id" in line:
                line = "# kms_keyring_name   = \"{}\"\n# kms_cryptokey_name = \"{}\"".format(kms_keyring_name, kms_cryptokey_name)
            else:
                if "kms_keyring_name" in line:
                    continue

                if "kms_cryptokey_name" in line:
                    line = "kms_cryptokey_id = \"{}\"".format(kms_cryptokey_id)

            lines.append(line.rstrip())
    
    # Rewrite the existing terraform.tfvars
    with open(tfvars_file, 'w') as f:
        f.writelines("%s\n" %line for line in lines)

# Use argparse to determine user's desired action, encryption or decryption of terraform.tfvars
def main():
    parser = argparse.ArgumentParser(description="This script encrypts or decrypts the secrets  \
                                    inside the user-specified terraform.tfstate file by         \
                                    prompting the user for one of the three deployment types    \
                                    (single, multi-region, dc-only). Select the mode by setting \
                                    a flag: -e for encryption or -d for decryption")

    parser.add_argument("-e", help="run this script in encryption mode", action='store_true')
    parser.add_argument("-d", help="run this script in decryption mode", action='store_true')

    args = parser.parse_args()
    
    if args.e:
        print("Encryption mode selected...\n")
        encrypt_tfvars_secrets()
    elif args.d:
        print("Decryption mode selected...\n")
        decrypt_tfvars_secrets()
    else:
        print("[gcp_kms_encrypt_secrets.py] No mode selected, set -e for encryption or -d for decryption\n")


if __name__ == '__main__':
    main()

