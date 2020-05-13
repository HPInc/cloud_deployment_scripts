#!/usr/bin/python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import os
from google.cloud    import kms_v1
from google.oauth2   import service_account


SECRETS_START_FLAG = "# <-- Start of secrets section, do not edit this line. -->"

class Tfvars_Encryptor_GCP:
    """Tfvars_Encryptor_GCP is used to automate the encryption or decryption of secrets in a terraform 
    tfvars file so that it is ready to be used for terraform deployments using encrypted secrets.

    Attributes:
        tfvars_path (str)          Path to the terraform.tfvars file.
        tfvars_data (dict)         Holds key value pairs for all terraform.tfvars configuration data.
        tfvars_secrets (dict)      Holds key value pairs for all terraform.tfvars secrets.
        max_key_length (int)       Longest string length of a tfvars_secrets key used to write secrets left-justified.
        gcp_credentials_file (str) Path to the GCP credentials file used for GCP KMS.
        gcp_credentials (object)   GCP Credentials object for a GCP service account.
        kms_client (object)        Instance of GCP Key Management Service Client.
        project_id (str)           GCP project ID associated with the GCP service account.
        location (str)             Defaulted to use "global" as the location.
        key_ring_id (str)          Defaulted to use "cas_keyring" as a key ring ID.
        crypto_key_id (str)        Defaulted to use "cas_key" as a crypto key ID.
        crypto_key_path (str)      Full GCP resource path to the crypto key being used to encrypt / decrypt.

    Methods:
        __init__(self, tfvars_path)
        create_crypto_key(crypto_key_id)
        create_key_ring(key_ring_id)
        decrypt_ciphertext(ciphertext)
        decrypt_file(file_path)
        decrypt_tfvars_secrets()
        encrypt_file(file_path)
        encrypt_plaintext(plaintext)
        encrypt_tfvars_secrets()
        initialize_keyring(key_ring_id)
        initialize_cryptokey(crypto_key_id)
        get_crypto_keys(key_ring_id)
        get_key_rings()
        read_tfvars(tfvars_file)
        write_new_tfvars()
    """

    def __init__(self, tfvars_path):
        """Tfvars_Encryptor_GCP Class Constructor to initialize the object.
        
        Args: 
            tfvars_path (str):      a full path to the terraform.tfvars file
        """

        # Read tfvars data and secrets into dictionaries
        self.tfvars_path = tfvars_path
        self.tfvars_data, self.tfvars_secrets = self.read_tfvars(tfvars_path)

        # Find the max string length of all the keys to left-justify align them
        self.max_key_length = max(map(len, self.tfvars_secrets))

        # Set GCP credentials instance variable from tfvars_data
        self.gcp_credentials_file = self.tfvars_data.get("gcp_credentials_file")

        # Create a client for the KMS API using the provided GCP service account
        self.gcp_credentials = service_account.Credentials.from_service_account_file(self.gcp_credentials_file)
        self.kms_client      = kms_v1.KeyManagementServiceClient(credentials = self.gcp_credentials)

        # GCP KMS resource variables
        self.project_id      = self.tfvars_data.get("gcp_project_id")
        self.location        = "global"
        self.key_ring_id     = self.initialize_keyring("cas_keyring")
        self.crypto_key_id   = self.initialize_cryptokey("cas_key")
        self.crypto_key_path = self.kms_client.crypto_key_path_path(self.project_id, self.location, self.key_ring_id, self.crypto_key_id)


    def create_crypto_key(self, crypto_key_id):
        """A method to create a crypto key on GCP KMS.
        
        Args:
            crypto_key_id (str): the name of the crypto key to be created
        Returns:
            string: the name of the crypto key created
        """

         # Create the crypto key object template
        purpose    = kms_v1.enums.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT
        crypto_key = { "purpose": purpose }

        # Create a crypto key for the given key ring
        parent   = self.kms_client.key_ring_path(self.project_id, self.location, self.key_ring_id)
        response = self.kms_client.create_crypto_key(parent, crypto_key_id, crypto_key)

        return response.name


    def create_key_ring(self, key_ring_id):
        """A method to create a key ring on GCP KMS.
        
        Args:
            key_ring_id (str): the name of the key ring to be created
        Returns:
            string: the name of the key ring created
        """

        # Create the key ring object template
        keyring_path = self.kms_client.key_ring_path(self.project_id, self.location, key_ring_id)
        keyring      = {"name": keyring_path}

        # Create a key ring
        parent   = self.kms_client.location_path(self.project_id, self.location)
        response = self.kms_client.create_key_ring(parent, key_ring_id, keyring)

        return response.name


    def decrypt_ciphertext(self, ciphertext):
        """A method that decrypts ciphertext.

        Uses GCP KMS to decrypt ciphertext back to plaintext using the provided
        symmetric crypto key that belongs to this instance.
        
        Args:
            ciphertext (str): the ciphertext being decrypted
        Returns:
            string: the plaintext
        """

        # Convert ciphertext string to a byte string, then Base64 decode it
        ciphertext = base64.b64decode(ciphertext.encode("utf-8"))

        # Use the KMS API to decrypt the data
        response = self.kms_client.decrypt(self.crypto_key_path, ciphertext)

        # Decode Base64 plaintext
        plaintext = response.plaintext.decode("utf-8")

        return plaintext


    def decrypt_file(self, file_path):
        """A method that decrypts the contents of a text file.

        Uses GCP KMS to decrypt ciphertext back to plaintext using the provided
        symmetric crypto key that belongs to this instance.
        
        Args:
            file_path (str): the path of the text file being decrypted
        Returns:
            string: the path to the decrypted text file created
        """

        try:
            print("Decrypting file: {}...".format(file_path))

            with open(file_path) as f:
                f_ciphertext = f.read()
        
            f_plaintext = self.decrypt_ciphertext(f_ciphertext)

            # Removes the .encrypted appended using this encryptor
            file_path_decrypted = "{}.decrypted".format(file_path).replace(".encrypted", "")

            with open(file_path_decrypted, "w") as f:
                f.write(f_plaintext)

        except Exception as err:
            print("An exception occurred decrypting file.")
            print("{}\n".format(err))
            raise SystemExit()
        
        return file_path_decrypted


    def decrypt_tfvars_secrets(self):
        """A method that decrypts the secrets contained in the terraform.tfvars file.

        This method contains the logic for handling the decryption of the secrets 
        and any file paths associated with it using GCP KMS. Once decrypted, it calls 
        write_new_tfvars() to write all secrets to a new terraform.tfvars file. 
        """    

        # Set crypto key path to use kms_cryptokey_id
        self.crypto_key_path = self.tfvars_data.get("kms_cryptokey_id")

        # Decrypt all secrets
        try:
            for secret in self.tfvars_secrets:
                # Additional handling needed if the string is a path to a file (IE. cam_credentials_file)
                if os.path.isfile(self.tfvars_secrets.get(secret)):
                    self.tfvars_secrets[secret] = self.decrypt_file(self.tfvars_secrets.get(secret))
                else:
                    print("Decrypting {}...".format(secret))
                    self.tfvars_secrets[secret] = self.decrypt_ciphertext(self.tfvars_secrets.get(secret))
            
            # Write encrypted secrets into new terraform.tfvars file
            self.write_new_tfvars()
            print("\nSuccessfully decrypted all secrets!\n")

        except Exception as err:
            print("An exception occurred decrypting secrets:")
            print("{}\n".format(err))
            raise SystemExit()


    def encrypt_file(self, file_path):
        """A method that encrypts the contents of a text file.

        Uses GCP KMS to encrypt the plaintext in a file to ciphertext using 
        the provided symmetric crypto key that belongs to this instance.
        
        Args:
            file_path (str): the path of the text file being encrypted
        Returns:
            string: the path to the encrypted text file created
        """

        try:
            print("Encrypting file: {}...".format(file_path))
            
            with open(file_path) as f:
                f_string = f.read()

            f_encrypted_string = self.encrypt_plaintext(f_string)
            file_path_encrypted = "{}.encrypted".format(file_path).replace(".decrypted", "")
            
            with open(file_path_encrypted, "w") as f:
                f.write(f_encrypted_string)

        except Exception as err:
            print("An exception occurred encrypting the file:")
            print("{}\n".format(err))
            raise SystemExit()
        
        return file_path_encrypted


    def encrypt_plaintext(self, plaintext):
        """A method that encrypts plaintext.

        Uses GCP KMS to encrypt plaintext to ciphertext using the provided
        symmetric crypto key that belongs to this instance.
        
        Args:
            ciphertext (str): the plainttext being encrypted
        Returns:
            string: the ciphertext
        """

        # Use the KMS API to encrypt the data.
        response = self.kms_client.encrypt(self.crypto_key_path, plaintext.encode("utf-8"))

        # Base64 encoding of ciphertext
        ciphertext = base64.b64encode(response.ciphertext).decode("utf-8")

        return ciphertext


    def encrypt_tfvars_secrets(self):
        """A method that encrypts secrets contained in the terraform.tfvars file.

        This method contains the logic for handling the encryption of the secrets 
        and any file paths associated with it using GCP KMS. Once encrypted, it calls 
        write_new_tfvars() to write all secrets to a new terraform.tfvars file. 
        """    

        # Encrypt all secrets found in the tfvars_secrets dictionary
        try:
            for secret in self.tfvars_secrets:
                # Additional handling needed if the string is a path to a file (IE. cam_credentials_file)
                if os.path.isfile(self.tfvars_secrets.get(secret)):
                    self.tfvars_secrets[secret] = self.encrypt_file(self.tfvars_secrets.get(secret))
                else:
                    print("Encrypting {}...".format(secret))
                    self.tfvars_secrets[secret] = self.encrypt_plaintext(self.tfvars_secrets.get(secret))

            # Write encrypted secrets into new terraform.tfvars file
            self.write_new_tfvars()
            print("\nSuccessfully encrypted all secrets!\n")

        except Exception as err:
            print("An exception occurred encrypting secrets:")
            print("{}\n".format(err))
            raise SystemExit()


    def initialize_cryptokey(self, crypto_key_id):
        """A method that initializes this instance's crypto key.

        This initialization method is called in the constructor to
        create a default crypto key if it doesn't exist. If the key
        exists already, then reuse it for this instance.
        
        Args:
            crypto_key_id (str): crypto key used to encrypt and decrypt
        Returns:
            string: the crypto key used
        """

        crypto_keys_list = self.get_crypto_keys(self.key_ring_id)

        # Create the crypto key only if it doesn't exist
        if crypto_key_id not in crypto_keys_list:
            try:
                self.create_crypto_key(crypto_key_id)
                print("Created key: {}\n".format(crypto_key_id))
                
            except Exception as err:
                print("An exception occurred creating new crypto key:")
                print("{}".format(err))
                raise SystemExit()
        else:
            print("Using existing crypto key: {}\n".format(crypto_key_id))
        
        return crypto_key_id


    def initialize_keyring(self, key_ring_id):
        """A method that initializes this instance's key ring.

        This initialization method is called in the constructor to
        create a default key ring if it doesn't exist.
        
        Args:
            key_ring_id (str): key ring being created
        Returns:
            string: the key ring used
        """

        key_rings_list = self.get_key_rings()

        # Create the key ring only if it doesn't exist
        if key_ring_id not in key_rings_list:
            try:
                self.create_key_ring(key_ring_id)
                print("Created key ring: {}\n".format(key_ring_id))
        
            except Exception as err:
                print("An exception occurred creating new key ring:")
                print("{}".format(err))
                raise SystemExit()
        else: 
            print("Using existing key ring: {}\n".format(key_ring_id))

        return key_ring_id


    def get_crypto_keys(self, key_ring_id):
        """A method that retrieves a list of crypto keys associated with a key ring.

        This method returns a list of all the crypto keys associated with a specific key ring.
        
        Args:
            key_ring_id (str): a GCP KMS key ring
        Returns:
            list: a list of all the crypto keys associated with the key ring argument.
        """

        parent   = self.kms_client.key_ring_path(self.project_id, self.location, key_ring_id)
        response = self.kms_client.list_crypto_keys(parent)

        # Access the name property and split string from the right. [2] to get the string after the separator
        # eg. name: "projects/user-terraform/locations/global/keyRings/cas_keyring/cryptoKeys/cas_key"
        crypto_keys_list = list(map(lambda key: key.name.rpartition('/')[2], response))

        return crypto_keys_list


    def get_key_rings(self):
        """A method that retrieves a list of key rings.

        This method returns a list of all the key rings associated 
        with the GCP service account.
        
        Returns:
            list: a list of all the key rings
        """

        parent   = self.kms_client.location_path(self.project_id, self.location)
        response = self.kms_client.list_key_rings(parent)

        # Access the name property and split string from the right. [2] to get the string after the separator
        # eg. name: "projects/user-terraform/locations/global/keyRings/cas_keyring"
        key_rings_list = list(map(lambda key_ring: key_ring.name.rpartition('/')[2], response))

        return key_rings_list


    def read_tfvars(self, tfvars_file):
        """A method that reads terraform.tfvars for all configuration data.

        This method reads a terraform.tfvars file for all the user-provided 
        configuration data above the secrets.
        Args:
            tfvars_file (str): a path to a terraform.tfvars file
        Returns:
            tuple containing:
                dict: key value pairs for all the terraform.tfvars data
                dict: key value pairs for all the terraform.tfvars secrets
        """

        tf_data = {}
        tf_secrets = {}

        begin_reading_secrets = False

        with open(tfvars_file, 'r') as f:
            for line in f:
                line = line.strip()

                if SECRETS_START_FLAG in line:
                    begin_reading_secrets = True
                    continue

                # Skip blank lines and comment lines
                # "not line" must come first using short circuiting to avoid string index out of range error
                if not line or line[0] in ("#"):
                    continue
                
                # Split the line into key value pairs using the first delimiter
                key, value = map(str.strip, line.split('=', 1))

                if begin_reading_secrets:
                    tf_secrets[key] = value.replace("\"", "")
                else:
                    tf_data[key] = value.replace("\"", "")

        return tf_data, tf_secrets


    def write_new_tfvars(self):
        """A method that writes a new terraform.tfvars file

        This method writes a new terraform.tfvars file that is ready to be used by
        Terraform after encrypting or decrypting. 
        """

        # Parse existing tfvars and store each line into a list
        lines = []
        
        with open(self.tfvars_path, 'r') as f:
            for line in f:
                
                # Remove leading and trailing whitespace including "\n" and "\t"
                line = line.strip()

                # Append the crypto key path to kms_cryptokey_id line
                if "kms_cryptokey_id =" in line:
                    if not self.tfvars_data.get("kms_cryptokey_id"):
                        lines.append("{} = \"{}\"".format("kms_cryptokey_id", self.crypto_key_path))
                    else:
                        lines.append("# {} = \"{}\"".format("kms_cryptokey_id", self.crypto_key_path))
                    continue

                # Blank lines and comments are unchanged
                # "not line" must come first using short circuit to avoid string index out of range error
                if not line or line[0] in ("#"):
                    lines.append(line)
                    continue
                
                # Need to keep the .strip() here to sanitize the key being read
                key = line.split("=")[0].strip()

                if key in self.tfvars_secrets.keys():
                    # Left justify all the secrets with space as padding on the right
                    lines.append("{} = \"{}\"".format(key.ljust(self.max_key_length, " "), self.tfvars_secrets.get(key)))
                else:
                    lines.append(line)

        # Add .backup postfix to the original tfvars file
        print("Creating backup of terraform.tfvars...")
        os.rename(self.tfvars_path, "{}.backup".format(self.tfvars_path))

        # Rewrite the existing terraform.tfvars
        print("Writing new terraform.tfvars...")
        with open(self.tfvars_path, 'w') as f:
            f.writelines("%s\n" %line for line in lines)


def main():
    # Set up argparse
    parser_description = ("Creates GCP KMS keyring and key, and uses the key to encrypt or decrypt secrets in the specified terraform.tfvars."
                          "The script encrypts by default. To decrypt instead, add the -d flag.")

    parser = argparse.ArgumentParser(description=parser_description)

    parser.add_argument("tfvars", help="specify the path to terraform.tfvars file")
    parser.add_argument("-d", help="decrypt secrets in terraform.tfvars specified", action='store_true')

    args = parser.parse_args()
    
    # Instantiate a new Tfvars_Encryptor_GCP with the tfvars path
    tfvars_encryptor_gcp = Tfvars_Encryptor_GCP(args.tfvars)
    
    # Abort the script if GCP credentials is missing
    if not tfvars_encryptor_gcp.tfvars_data.get("gcp_credentials_file"):
        print("Missing gcp_credentials_file in tfvars. Ensure gcp_credentials_file is valid and try again.\n")
        raise SystemExit()

    # Encryption is the default, user can specify a -d flag for decryption
    if args.d:
        # Abort the decryption if there is not a kms_cryptokey_id in the tfvars file
        if not tfvars_encryptor_gcp.tfvars_data.get("kms_cryptokey_id"):
            print("No kms_cryptokey_id present in tfvars. Ensure the secrets are encrypted and try again.\n")
            raise SystemExit()

        tfvars_encryptor_gcp.decrypt_tfvars_secrets()
    else:
        # Abort the encryption if the tfvars is already encrypted with a kms_cryptokey_id present
        if tfvars_encryptor_gcp.tfvars_data.get("kms_cryptokey_id"):
            print("Detected kms_cryptokey_id in tfvars. Ensure secrets are not already encrypted and try again.\n")
            raise SystemExit()

        tfvars_encryptor_gcp.encrypt_tfvars_secrets()


if __name__ == '__main__':
    main()

