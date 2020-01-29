# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/usr/local/bin/python3

from google.cloud import kms_v1
from google.cloud.kms_v1 import enums
import os
import base64
import json
import ntpath

# Enter the path to the GCP credentials for the service account
GCP_CREDENTIALS_FILE = "/path/to/gcp_cred.json"

# Enter the GCP project ID associated with the provided GCP service account
PROJECT_ID = "your-project-1234"

# Choose and enter new names for the key ring and crypto key.
# Note: For security, keyring names cannot be changed or deleted once created.
KEY_RING_ID = "create-a-key-ring-name"
CRYPTO_KEY  = "create-a-crypto-key-name"

# Secrets to be encrypted using newly created crypto key
DC_ADMIN_PASSWORD           = "SecuRe_pwd1"
SAFE_MODE_ADMIN_PASSWORD    = "SecuRe_pwd2"
AD_SERVICE_ACCOUNT_PASSWORD = "SecuRe_pwd3"
PCOIP_REGISTRATION_CODE     = "ABCDEFGHIJKL@0123-4567-89AB-CDEF"
CAM_CREDENTIALS_FILE        = "/path/to/cam_cred.json"

# Set the location to use "global"
LOCATION = "global"

# Set environment variables to be used by KMS client
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = GCP_CREDENTIALS_FILE

# List KMS key rings
def list_key_rings(client, project_id, location):
    parent        = client.location_path(project_id, location)
    response      = client.list_key_rings(parent)
    response_list = list(response)

    if len(response_list) > 0:
        print("Key rings:")
        for key_ring in response_list:
            print(key_ring.name)
        print("")
    else:
        print("No key rings found.\n")


# Create KMS key ring
def create_key_ring(client, project_id, location, key_ring_id):
    parent = client.location_path(project_id, location)

    # The key ring object template
    keyring_path = client.key_ring_path(project_id, location, key_ring_id)
    keyring      = { "name": keyring_path }

    # Create a key ring
    response = client.create_key_ring(parent, key_ring_id, keyring)

    return response.name


# Create crypto key within a key ring
def create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id):
    parent = client.key_ring_path(project_id, location, key_ring_id)

    # Create the crypto key object template
    purpose    = enums.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT
    crypto_key = { "purpose": purpose }

    # Create a crypto key for the given key ring
    response = client.create_crypto_key(parent, crypto_key_id, crypto_key)

    return response.name


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


# Decrypt ciphertext using the provided symmetric crypto key
def decrypt_ciphertext(client, project_id, location, key_ring_id, crypto_key_id,
                      ciphertext):
    # Resource name of the crypto key
    crypto_key_path = client.crypto_key_path_path(project_id, location, key_ring_id,
                        crypto_key_id)

    # UTF-8 encoding of ciphertext
    ciphertext = ciphertext.encode("utf-8")

    # Base64 decoding of ciphertext
    ciphertext = base64.b64decode(ciphertext)

    # Use the KMS API to decrypt the data.
    response = client.decrypt(crypto_key_path, ciphertext)

    # Decode Base64 plaintext
    plaintext = response.plaintext.decode()
    return plaintext


# Encrypt CAM JSON credential file
def encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id):
    # CAM credentials file path to be encrypted
    cam_credentials_file = CAM_CREDENTIALS_FILE

    # Directory and file name of CAM JSON credentials
    cam_credentials_dirname  = ntpath.dirname(cam_credentials_file)
    cam_credentials_basename = ntpath.basename(cam_credentials_file)

    # Encrypt CAM JSON credentials
    try:
        with open(cam_credentials_file) as cam_credentials:
            cam_credentials = json.load(cam_credentials)
    
        cam_credentials_string = json.dumps(cam_credentials)
        cam_credentials_encrypted = encrypt_plaintext(client, project_id, location, key_ring_id, crypto_key_id,
                                    cam_credentials_string)
        print("Encrypted CAM credentials:")
        print("{}\n".format(cam_credentials_encrypted))

        with open("{}.encrypted".format(cam_credentials_file), "w") as cam_credentials_encrypted_file:
            cam_credentials_encrypted_file.write(cam_credentials_encrypted)
            
    except Exception as err:
        print("An exception occurred encrypting CAM JSON credentials:")
        print(err)
        print("")


# Driver of this script
def main():
    # Create an API client for the KMS API using the provided GCP service account
    client = kms_v1.KeyManagementServiceClient()

    # Resource names of the location associated with the key rings
    project_id    = PROJECT_ID
    key_ring_id   = KEY_RING_ID
    crypto_key_id = CRYPTO_KEY
    location      = LOCATION

    # Secrets in plaintext
    secrets = {
        "dc_admin_password"           : DC_ADMIN_PASSWORD,
        "safe_mode_admin_password"    : SAFE_MODE_ADMIN_PASSWORD,
        "ad_service_account_password" : AD_SERVICE_ACCOUNT_PASSWORD,
        "pcoip_registration_code"     : PCOIP_REGISTRATION_CODE
    }

    # Create a key ring
    try:
        kms_keyring_id = create_key_ring(client, project_id, location, key_ring_id)
        print("Created key ring: {}\n".format(kms_keyring_id))

    except Exception as err:
        print("An exception occurred creating new key ring:")
        print(err)
        print("")

    # List all key rings
    list_key_rings(client, project_id, location)

    # Create a crypto key
    try:
        kms_cryptokey_id = create_crypto_key(client, project_id, location, key_ring_id, crypto_key_id)
        print("kms_cryptokey_id: {}\n".format(kms_cryptokey_id))

    except Exception as err:
        print("An exception occurred creating new crypto key:")
        print(err)
        print("")
    
    # Encrypt secrets including CAM credentials
    try:
        for secret in secrets:
            print("Encrypting {}...".format(secret))

            print("{0}: {1}".format(secret, secrets.get(secret)))

            ciphertext = encrypt_plaintext(client, project_id, location, key_ring_id, crypto_key_id, secrets.get(secret))
            print("{0}: {1}\n".format(secret, ciphertext))

        encrypt_cam_credentials(client, project_id, location, key_ring_id, crypto_key_id)
            
    except Exception as err:
        print("An exception occurred encrypting secrets:")
        print(err)
        print("")
      

# Entry point to this script
if __name__ == '__main__':
    main()