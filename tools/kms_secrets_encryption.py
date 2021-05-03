#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import importlib
import os
import site
import subprocess
import sys
import textwrap
import json
from abc import ABC, abstractmethod


SECRETS_START_FLAG = "# <-- Start of secrets section, do not edit this line. -->"


def import_or_install_module(pypi_package_name, module_name = None):
    """A function that imports a Python top-level package or module. 
    If the required package is not installed, it will install the package before importing it again.

    Args:
        pypi_package_name (str): the name of the PyPI package to be installed
        module_name (str): the import name of the module if it is different than the PyPI package name

    Returns:
        module: the top-level package or module
    """

    if module_name is None:
        module_name = pypi_package_name

    try:
        module = importlib.import_module(module_name)
        print(f"Successfully imported {module_name}.")

    except ImportError:
        install_cmd = f'{sys.executable} -m pip install {pypi_package_name} --user'

        install_permission = input(
            f"This script requires {pypi_package_name} but it is not installed.\n"
            f"Proceed to install this package by running '{install_cmd}' (y/n)? ").strip().lower()

        if install_permission not in ('y', 'yes'):
            print(f"{pypi_package_name} is not installed. Exiting...")
            sys.exit(1)

        subprocess.check_call(install_cmd.split(' '))

        print(f"Successfully installed {pypi_package_name}.")

        # Refresh sys.path to detect new modules in user's home directory.
        importlib.reload(site)

        module = importlib.import_module(module_name)
        print(f"Successfully imported {module_name}.")

    except Exception as err:
        print(f"An exception occurred importing {module_name}.\n")
        raise SystemExit(err)

    return module


class Tfvars_Parser:
    """Tfvars_Parser is used to read and parse data from a Terraform tfvars file. 
    It is used by the Tfvars_Encryptor class to automate the encryption or 
    decryption of secrets in a Terraform tfvars file so that it is ready to 
    be used for Terraform deployments using encrypted secrets.

    Attributes
    ----------
    tfvars_path : str
        Path to the terraform.tfvars file.
    tfvars_data : dict
        Dictionary containing key value pairs for all terraform.tfvars configuration data.
    tfvars_secrets : dict
        Dictionary containing key value pairs for all terraform.tfvars secrets.
    max_key_length : int 
        Longest string length of a tfvars_secrets key used to write secrets left-justified.

    Methods
    -------
        __init__(tfvars_path)
        read_tfvars(tfvars_file)
    """

    def __init__(self, tfvars_path):
        """Tfvars_Parser class constructor to initialize the object.
        
        Args
        ---- 
        tfvars_path : str
            Path to the terraform.tfvars file being parsed.
        """

        # Read tfvars data and secrets into dictionaries
        self.tfvars_path = tfvars_path
        self.tfvars_data, self.tfvars_secrets = self.read_tfvars(tfvars_path)

        # Find the max string length of all the keys to left-justify align them
        self.max_key_length = max(map(len, self.tfvars_secrets))


    def read_tfvars(self, tfvars_file):
        """A method that reads terraform.tfvars for all configuration data.
        This method reads a terraform.tfvars file for all the user-provided 
        configuration data above the secrets.

        Args
        ----
        tfvars_file : str
            Path to the terraform.tfvars file being parsed.

        Returns
        -------
        tf_data, tf_secrets : tuple (dict, dict)
            tf_data:    key value pairs for all the terraform.tfvars data
            tf_secrets: key value pairs for all the terraform.tfvars secrets
        """

        tf_data = {}
        tf_secrets = {}

        begin_reading_secrets = False

        try:
            with open(tfvars_file) as f:
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
                    key, value = map(str.strip, line.split("=", 1))

                    if begin_reading_secrets:
                        tf_secrets[key] = value.replace("\"", "")
                    else:
                        tf_data[key] = value.replace("\"", "")

        except Exception as err:
            print("An exception occurred reading the terraform.tfvars file:\n")
            raise SystemExit(err)
        
        if not tf_secrets:
            err = """\
            An exception occurred reading the secrets in the terraform.tfvars file:\n
            Ensure the start of secrets marker is present before the secrets section
            in the terraform.tfvars file and try again.
            i.e. '# <-- Start of secrets section, do not edit this line. -->'"""

            raise SystemExit(textwrap.dedent(err))

        return tf_data, tf_secrets


class Tfvars_Encryptor(ABC):
    """This is an abstract super class that is inherited by 
    AWS_Tfvars_Encryptor and GCP_Tfvars_Encryptor.

    It contains common attributes and methods that are used by the sub 
    encryptor classes to automate the encryption and decryption of 
    terraform.tfvars files.

    Attributes
    ----------
    tfvars_parser : object
        Instance of Tfvars_Parser used to read and store terraform.tfvars 
        secrets and configuration data.
    kms_client : object
        Instance of Key Management Service Client.
    credentials_file : str
        Path to the KMS client credentials file.

    Methods
    -------
    Abstract methods:
        __init__(tfvars_parser)
        create_crypto_key(crypto_key_id) 
        decrypt_ciphertext(ciphertext, base64_encoded)
        encrypt_plaintext(plaintext, base64_encoded)
        get_crypto_keys()
        initialize_cryptokey(crypto_key_id)
    
    Concrete methods:
        decrypt_file(file_path)
        decrypt_tfvars_secrets()
        encrypt_file(file_path)
        encrypt_tfvars_secrets()
        write_new_tfvars()
    """

    @abstractmethod
    def __init__(self, tfvars_parser):
        """Tfvars_Encryptor class constructor to initialize the object.

        Args
        ----
        tfvars_parser : object 
            Instance of Tfvars_Parser class.
        """

        self.tfvars_parser    = tfvars_parser
        self.kms_client       = None
        self.credentials_file = None


    @abstractmethod
    def create_crypto_key(self, crypto_key_id): pass


    @abstractmethod
    def decrypt_ciphertext(self, ciphertext, base64_encoded): pass


    @abstractmethod
    def encrypt_plaintext(self, plaintext, base64_encoded): pass


    @abstractmethod
    def initialize_cryptokey(self, crypto_key_id): pass


    def decrypt_file(self, file_path):
        """A method that decrypts the contents of a text file.

        Uses the KMS client to decrypt ciphertext back to plaintext using the 
        provided symmetric crypto key that belongs to this instance.

        Args
        ----
        file_path : str
            Path of the text file being decrypted.

        Returns
        -------
        file_path_decrypted : str
            Path to the decrypted text file created.
        """

        try:
            print(f"Decrypting file: {file_path}...")

            # read binary file
            with open(file_path, 'rb') as f:
                f_ciphertext = f.read()

            f_plaintext = self.decrypt_ciphertext(f_ciphertext)

            # Removes the .encrypted appended using this encryptor
            file_path_decrypted = f"{file_path}.decrypted".replace(".encrypted", "")

            with open(file_path_decrypted, "w") as f:
                f.write(f_plaintext)

        except Exception as err:
            print("An exception occurred decrypting file.\n")
            raise SystemExit(err)

        return file_path_decrypted


    def decrypt_tfvars_secrets(self):
        """A method that decrypts the secrets contained in the terraform.tfvars file.

        This method contains the logic for handling the decryption of the secrets 
        and any file paths associated with it using the KMS client. Once decrypted, it 
        calls write_new_tfvars() to write all secrets to a new terraform.tfvars file. 
        """

        # GCP uses kms_cryptokey_id while AWS uses customer_master_key_id
        if type(self).__name__ == "GCP_Tfvars_Encryptor":
            self.crypto_key_path = self.tfvars_parser.tfvars_data.get("kms_cryptokey_id")

        if type(self).__name__ == "AWS_Tfvars_Encryptor":
            self.customer_master_key_id = self.tfvars_parser.tfvars_data.get("customer_master_key_id")

        # Decrypt all secrets
        try:
            for secret in self.tfvars_parser.tfvars_secrets:
                # Additional handling needed if the string is a path to a file
                # e.g. cas_mgr_deployment_sa_file
                if os.path.isfile(self.tfvars_parser.tfvars_secrets.get(secret)):
                    self.tfvars_parser.tfvars_secrets[secret] = self.decrypt_file(self.tfvars_parser.tfvars_secrets.get(secret))
                else:
                    print(f"Decrypting {secret}...")
                    self.tfvars_parser.tfvars_secrets[secret] = self.decrypt_ciphertext(self.tfvars_parser.tfvars_secrets.get(secret), True)

            # Write encrypted secrets into new terraform.tfvars file
            self.write_new_tfvars()
            print("\nSuccessfully decrypted all secrets!\n")

        except Exception as err:
            print("An exception occurred decrypting secrets:\n")
            raise SystemExit(err)


    def encrypt_file(self, file_path):
        """A method that encrypts the contents of a text file.

        Uses the KMS client to encrypt the plaintext in a file to ciphertext using 
        the provided symmetric crypto key that belongs to this instance.

        Args
        ----
        file_path : str
            Path of the text file being encrypted.

        Returns
        -------
        file_path_encrypted : str
            Path to the encrypted text file created.
        """

        try:
            print(f"Encrypting file: {file_path}...")
            
            with open(file_path) as f:
                f_string = f.read()

            f_encrypted_string = self.encrypt_plaintext(f_string)
            file_path_encrypted = f"{file_path}.encrypted".replace(".decrypted", "")
            
            # write byte string into file
            with open(file_path_encrypted, "wb") as f:
                f.write(f_encrypted_string)

        except Exception as err:
            print("An exception occurred encrypting the file:\n")
            raise SystemExit(err)

        return file_path_encrypted


    def encrypt_tfvars_secrets(self):
        """A method that encrypts secrets contained in the terraform.tfvars file.

        This method contains the logic for handling the encryption of the secrets 
        and any file paths associated with it using the KMS client. Once encrypted, it 
        calls write_new_tfvars() to write all secrets to a new terraform.tfvars file. 
        """

        # Encrypt all secrets found in the tfvars_secrets dictionary
        try:
            for secret in self.tfvars_parser.tfvars_secrets:
                # Additional handling needed if the string is a path to a file
                # e.g. cas_mgr_deployment_sa_file
                if os.path.isfile(self.tfvars_parser.tfvars_secrets.get(secret)):
                    self.tfvars_parser.tfvars_secrets[secret] = self.encrypt_file(self.tfvars_parser.tfvars_secrets.get(secret))
                else:
                    print(f"Encrypting {secret}...")
                    self.tfvars_parser.tfvars_secrets[secret] = self.encrypt_plaintext(self.tfvars_parser.tfvars_secrets.get(secret), True)

            # Write encrypted secrets into new terraform.tfvars file
            self.write_new_tfvars()
            print("\nSuccessfully encrypted all secrets!\n")

        except Exception as err:
            print("An exception occurred encrypting secrets:\n")
            raise SystemExit(err)


    def write_new_tfvars(self):
        """A method that writes a new terraform.tfvars file.

        This method writes a new terraform.tfvars file that is ready to be used by
        Terraform after encrypting or decrypting. 
        """

        key_id = None
        key_value = None

        # GCP uses kms_cryptokey_id while AWS uses customer_master_key_id
        if type(self).__name__ == "GCP_Tfvars_Encryptor":
            key_id = "kms_cryptokey_id"
            key_value = self.crypto_key_path

        if type(self).__name__ == "AWS_Tfvars_Encryptor":
            key_id = "customer_master_key_id"
            key_value = self.customer_master_key_id

        # Parse existing tfvars and store each line into a list
        lines = []

        try:
            with open(self.tfvars_parser.tfvars_path) as f:
                for line in f:
                    
                    # Remove leading and trailing whitespace including "\n" and "\t"
                    line = line.strip()

                    # Append the crypto key value to key_id line
                    if key_id + " =" in line:
                        if not self.tfvars_parser.tfvars_data.get(key_id):
                            lines.append(f"{key_id} = \"{key_value}\"")
                        else:
                            lines.append(f"# {key_id} = \"{key_value}\"")
                        continue

                    # Blank lines and comments are unchanged
                    # "not line" must come first using short circuit to avoid string index out of range error
                    if not line or line[0] in ("#"):
                        lines.append(line)
                        continue

                    # Need to keep the .strip() here to sanitize the key being read
                    key = line.split("=")[0].strip()

                    if key in self.tfvars_parser.tfvars_secrets.keys():
                        # Left justify all the secrets with space as padding on the right
                        lines.append(f"{key.ljust(self.tfvars_parser.max_key_length, ' ')} = \"{self.tfvars_parser.tfvars_secrets.get(key)}\"")
                    else:
                        lines.append(line)

            # Add .backup postfix to the original tfvars file
            print("Creating backup of terraform.tfvars...")
            os.rename(self.tfvars_parser.tfvars_path, f"{self.tfvars_parser.tfvars_path}.backup")

            # Rewrite the existing terraform.tfvars
            print("Writing new terraform.tfvars...")
            with open(self.tfvars_parser.tfvars_path, "w") as f:
                f.writelines("%s\n" %line for line in lines)

        except Exception as err:
            print("An exception occurred writing the terraform.tfvars file:\n")
            raise SystemExit(err)


class GCP_Tfvars_Encryptor(Tfvars_Encryptor):
    """This is an concrete sub class that inherits from Tfvars_Encryptor.
    
    It contains attributes and methods specific to GCP KMS client to 
    automate the encryption and decryption of terraform.tfvars files.

    Attributes
    ----------
    gcp_credentials : object
        GCP Credentials object for a GCP service account.
    project_id : str
        GCP project ID associated with the GCP service account.
    location : str
        Defaulted to use "global" as the location.
    key_ring_id : str
        Defaulted to use "cas_keyring" as a key ring ID.
    crypto_key_id : str
        Defaulted to use "cas_key" as the crypto key ID.
    crypto_key_path : str
        Full GCP resource path to the crypto key being used to encrypt and decrypt.

    Methods
    -------
        __init__(tfvars_parser)
        create_crypto_key(crypto_key_id)
        decrypt_ciphertext(ciphertext, base64_encoded)
        encrypt_plaintext(plaintext, base64_encoded)
        get_crypto_keys(key_ring_id)
        get_key_rings()
        initialize_cryptokey(crypto_key_id)
        initialize_keyring(key_ring_id)
    """

    def __init__(self, tfvars_parser):
        """GCP_Tfvars_Encryptor class constructor to initialize the object.

        Args
        ----
        tfvars_parser : object 
            Instance of Tfvars_Parser class.
        """

        super().__init__(tfvars_parser)

        # Install and import the required GCP modules
        global kms
        global service_account
        kms = import_or_install_module("google-cloud-kms", "google.cloud.kms")
        service_account = import_or_install_module("google_oauth2_tool", "google.oauth2.service_account")

        # Set GCP credentials instance variable from tfvars_data
        self.credentials_file = self.tfvars_parser.tfvars_data.get("gcp_credentials_file")

        # Create a client for the KMS API using the provided GCP service account
        self.gcp_credentials = service_account.Credentials.from_service_account_file(self.credentials_file)
        self.kms_client      = kms.KeyManagementServiceClient(credentials = self.gcp_credentials)

        # GCP KMS resource variables
        with open(self.credentials_file) as f:
            cred_file_json=json.load(f)
        
        self.project_id      = cred_file_json["project_id"]
        self.location        = "global"
        self.key_ring_id     = self.initialize_keyring("cas_keyring")
        self.crypto_key_id   = self.initialize_cryptokey("cas_key")
        self.crypto_key_path = self.kms_client.crypto_key_path(self.project_id, self.location, self.key_ring_id, self.crypto_key_id)


    def create_crypto_key(self, crypto_key_id):
        """A method to create a crypto key on GCP KMS.

        Args
        ----
        crypto_key_id : str
            name of the crypto key to be created.

        Returns
        -------
        created_crypto_key.name : str 
            name of the crypto key created.
        """

         # Create the crypto key object template
        purpose    = kms.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT
        crypto_key = { "purpose": purpose }

        # Create a crypto key for the given key ring
        parent             = self.kms_client.key_ring_path(self.project_id, self.location, self.key_ring_id)
        created_crypto_key = self.kms_client.create_crypto_key(
            request={'parent': parent, 'crypto_key_id': crypto_key_id, 'crypto_key': crypto_key}
        )

        print(f"Created key ring: {created_crypto_key.name}\n")

        return created_crypto_key.name


    def decrypt_ciphertext(self, ciphertext, base64_encoded=False):
        """A method that decrypts ciphertext.

        Uses GCP KMS to decrypt ciphertext back to plaintext using the provided
        symmetric crypto key that belongs to this instance.

        Args
        ----
        ciphertext : str
            the ciphertext being decrypted.

        base64_encoded : boolean
            the boolean param shows whether the ciphertext is base64 encoded.

        Returns
        -------
        plaintext : str
            the decrypted secret in plaintext.
        """

        # Convert ciphertext string to a byte string, then Base64 decode it
        if base64_encoded:
            ciphertext = base64.b64decode(ciphertext.encode("utf-8"))

        # Use the KMS API to decrypt the data
        response = self.kms_client.decrypt(
            request={'name': self.crypto_key_path, 'ciphertext': ciphertext}
        )

        # Decode Base64 plaintext
        plaintext = response.plaintext.decode("utf-8")

        return plaintext


    def encrypt_plaintext(self, plaintext, base64_encoded=False):
        """A method that encrypts plaintext.

        Uses GCP KMS to encrypt plaintext to ciphertext using the provided
        symmetric crypto key that belongs to this instance.

        Args
        ----
        plaintext : str 
            the plainttext being encrypted.

        base64_encoded : boolean
            the boolean param shows whether the returned ciphertext need base64 encode.

        Returns
        -------
        ciphertext : str
            the encrypted secret in ciphertext.
        """

        # Use the KMS API to encrypt the data.
        response = self.kms_client.encrypt(
            request={'name': self.crypto_key_path, 'plaintext': plaintext.encode('utf-8')}
        )

        # Base64 encoding of ciphertext
        if base64_encoded:
            ciphertext = base64.b64encode(response.ciphertext).decode("utf-8")
        else:
            ciphertext = response.ciphertext

        return ciphertext


    def get_crypto_keys(self, key_ring_id):
        """A method that retrieves a list of crypto keys associated with a key ring.

        This method returns a list of all the crypto keys associated with a specific key ring.

        Args
        ----
        key_ring_id : str
            string ID for the GCP KMS key ring.

        Returns
        -------
        crypto_keys_list : list 
            a list of all the crypto keys associated with the key ring argument.
        """

        parent   = self.kms_client.key_ring_path(self.project_id, self.location, key_ring_id)
        response = self.kms_client.list_crypto_keys(request={'parent': parent})

        # Access the name property and split string from the right. [2] to get the string after the separator
        # eg. name: "projects/user-terraform/locations/global/keyRings/cas_keyring/cryptoKeys/cas_key"
        crypto_keys_list = list(map(lambda key: key.name.rpartition("/")[2], response))

        return crypto_keys_list


    def get_key_rings(self):
        """A method that retrieves a list of key rings.

        This method returns a list of all the key rings associated 
        with the GCP service account.

        Returns
        -------
        key_rings_list : list 
            a list of all the key rings.
        """

        parent   = f'projects/{self.project_id}/locations/{self.location}'
        response = self.kms_client.list_key_rings(request={'parent': parent})

        # Access the name property and split string from the right. [2] to get the string after the separator
        # eg. name: "projects/user-terraform/locations/global/keyRings/cas_keyring"
        key_rings_list = list(map(lambda key_ring: key_ring.name.rpartition("/")[2], response))

        return key_rings_list


    def initialize_cryptokey(self, crypto_key_id):
        """A method that initializes this instance's crypto key.

        This initialization method is called in the constructor to
        create a default crypto key if it doesn't exist. If the key
        exists already, then reuse it for this instance.

        Args
        ----
        crypto_key_id : str 
            the GCP crypto key ID used to encrypt and decrypt.

        Returns
        -------
        crypto_key_id : str
            the GCP crypto key ID used to encrypt and decrypt.
        """

        crypto_keys_list = self.get_crypto_keys(self.key_ring_id)

        # Create the crypto key only if it doesn't exist
        if crypto_key_id not in crypto_keys_list:
            try:
                self.create_crypto_key(crypto_key_id)
                print(f"Created key: {crypto_key_id}\n")
                
            except Exception as err:
                print("An exception occurred creating new crypto key:\n")
                raise SystemExit(err)
        else:
            print(f"Using existing crypto key: {crypto_key_id}\n")

        return crypto_key_id


    def initialize_keyring(self, key_ring_id):
        """A method that initializes this instance's key ring.

        This initialization method is called in the constructor to
        create a default key ring if it doesn't exist.

        Args
        ----
        key_ring_id : str 
            key ring being created.

        Returns
        -------
        key_ring_id : str 
            the key ring used.
        """

        key_rings_list = self.get_key_rings()

        # Create the key ring only if it doesn't exist
        if key_ring_id not in key_rings_list:
            try:
                parent   = f'projects/{self.project_id}/locations/{self.location}'
                key_ring = {}
                created_key_ring = self.kms_client.create_key_ring(
                    request={'parent': parent, 'key_ring_id': key_ring_id, 'key_ring': key_ring}
                )
                print(f"Created key ring: {key_ring_id}\n")

            except Exception as err:
                print("An exception occurred creating new key ring:\n")
                raise SystemExit(err)
        else: 
            print(f"Using existing key ring: {key_ring_id}\n")

        return key_ring_id


class AWS_Tfvars_Encryptor(Tfvars_Encryptor):
    """This is a concrete sub class that inherits from Tfvars_Encryptor.

    It contains attributes and methods specific to AWS KMS client to 
    automate the encryption and decryption of terraform.tfvars files.

    Attributes
    ----------
    aws_credentials : dict
        Dictionary containing two keys: aws_access_key_id and aws_secret_access_key.
    customer_master_key_id : str 
        Defaulted to use "cas_key" as a crypto key ID.

    Methods
    -------
        __init__(tfvars_parser)
        create_crypto_key(crypto_key_alias)
        decrypt_ciphertext(ciphertext, base64_encoded)
        encrypt_plaintext(plaintext, base64_encoded)
        initialize_aws_credentials(path)
        initialize_cryptokey(crypto_key_alias_name)
        get_crypto_keys()
    """

    def __init__(self, tfvars_parser):
        """AWS_Tfvars_Encryptor class constructor to initialize the object.

        Args
        ----
        tfvars_parser : object 
            instance of Tfvars_Parser class.
        """

        super().__init__(tfvars_parser)

        # Install and import the required AWS modules
        global boto3
        boto3 = import_or_install_module("boto3")

        # Set AWS credentials instance variables from tfvars_data
        self.credentials_file = self.tfvars_parser.tfvars_data.get("aws_credentials_file")

        # Create a client for the KMS API using the provided AWS credentials
        self.aws_credentials = self.initialize_aws_credentials(self.credentials_file)

        self.kms_client = boto3.client(
            "kms",
            aws_access_key_id     = self.aws_credentials.get("aws_access_key_id"),
            aws_secret_access_key = self.aws_credentials.get("aws_secret_access_key"),
            region_name           = self.tfvars_parser.tfvars_data.get("aws_region")
        )

        # AWS KMS resource variables
        self.customer_master_key_id = self.initialize_cryptokey("cas_key")


    def create_crypto_key(self, crypto_key_alias):
        """A method to create a crypto key on AWS KMS.

        Args
        ----
        crypto_key_alias : str 
            alias name of the crypto key being created.

        Returns
        ------
        customer_master_key_id : string
            customer_master_key_id value used for terraform.tfvars file.
        """

        # Use KMS client to create key and store the returned KeyId
        customer_master_key_id = self.kms_client.create_key().get("KeyMetadata").get("KeyId")
        # Give this KeyId an alias name
        self.kms_client.create_alias(
            # The alias to create. Aliases must begin with "alias/".
            AliasName = f"alias/{crypto_key_alias}",
            TargetKeyId = customer_master_key_id
        )

        print(f"Created {crypto_key_alias}: {customer_master_key_id}\n")

        return customer_master_key_id


    def decrypt_ciphertext(self, ciphertext, base64_encoded=False):
        """A method that decrypts ciphertext.

        Uses AWS KMS to decrypt ciphertext back to plaintext using the provided
        symmetric crypto key that belongs to this instance.

        Args
        ----
        ciphertext : str
            the ciphertext being decrypted.

        base64_encoded : boolean
            the boolean param shows whether the ciphertext is base64 encoded.

        Returns
        -------
        plaintext : str
            the decrypted secret in plaintext.
        """

        # Convert ciphertext string to a byte string, then Base64 decode it
        if base64_encoded:
            ciphertext = base64.b64decode(ciphertext.encode("utf-8"))

        # Use the KMS API to decrypt the data
        response = self.kms_client.decrypt(
                        KeyId = self.customer_master_key_id,
                        CiphertextBlob = ciphertext
                    )

        # Decode Base64 plaintext
        plaintext = response.get("Plaintext").decode("utf-8")

        return plaintext


    def encrypt_plaintext(self, plaintext, base64_encoded=False):
        """A method that encrypts plaintext.

        Uses AWS KMS to encrypt plaintext to ciphertext using the provided
        symmetric crypto key that belongs to this instance.

        Args
        ----
        ciphertext : str 
            the plainttext being encrypted.

        base64_encoded : boolean
            the boolean param shows whether the returned ciphertext need base64 encode.

        Returns
        -------
        ciphertext : str
            the encrypted secret in ciphertext.
        """

        # Use the KMS API to encrypt the data.
        response = self.kms_client.encrypt(
                        KeyId = self.customer_master_key_id, 
                        Plaintext = plaintext.encode("utf-8")
                    )

        # Base64 encoding of ciphertext
        if base64_encoded:
            ciphertext = base64.b64encode(response.get("CiphertextBlob")).decode("utf-8")
        else:
            ciphertext = response.get("CiphertextBlob")

        return ciphertext


    def get_crypto_keys(self):
        """A method that retrieves a list of crypto keys aliase names 
        associated with the AWS credentials in the region.

        Returns
        -------
        crypto_keys_list : list
            a list of all the crypto keys aliase names associated with the AWS credentials in the region.
        """

        # Use crypto keys data under the "Aliases" dict key
        response = self.kms_client.list_aliases().get("Aliases")

        # Access the "AliasName" property for each key entry by splitting string from the right. [2] to get the string after the separator
        # eg. response.get("Aliases") returns [{"AliasName": "<alias/AliasName>", "AliasArn": "<AliasArn>", "TargetKeyId": "<TargetKeyId>"}]
        crypto_keys_list = list(map(lambda key: key.get("AliasName").rpartition("/")[2], response))

        return crypto_keys_list


    def initialize_aws_credentials(self, file_path):
        """A method that parses the aws_access_key_id and aws_secret_access_key 
        from aws_credentials_file required for the KMS client.

        This initialization method is used in the constructor to
        initialize both the aws_access_key_id and aws_secret_access_key 
        by parsing the aws_credentials_file. 

        Args
        ----
        file_path : str 
            path to aws_credentials_file.

        Returns
        -------
        dict
            Dictionary containing the "aws_access_key_id" and "aws_secret_access_key".
        """

        aws_access_key_id = None
        aws_secret_access_key = None

        try:
            with open(file_path) as f:
                for line in f:
                    line = line.strip()
                    
                    # Skip blank lines and comment lines
                    # "not line" must come first using short circuiting to avoid string index out of range error
                    if not line or line[0] in ("#"):
                        continue

                    if "aws_secret_access_key" in line:
                        aws_secret_access_key = line.rpartition("=")[2].strip()
                        continue

                    if "aws_access_key_id" in line:
                        aws_access_key_id = line.rpartition("=")[2].strip()
                        continue

        except Exception as err:
            print("An exception occurred initializing AWS credentials:\n")
            raise SystemExit(err)

        return {    "aws_access_key_id": aws_access_key_id, 
                "aws_secret_access_key": aws_secret_access_key }


    def initialize_cryptokey(self, crypto_key_alias_name):
        """A method that initializes this instance's crypto key.

        This initialization method is called in the constructor to
        create a default crypto key if it doesn't exist. If the key
        exists already, then reuses it for this instance.

        Args
        ----
        crypto_key_alias_name : str
            the AWS crypto key alias name used to encrypt and decrypt.

        Returns
        -------
        customer_master_key_id : str 
            the AWS crypto key used to encrypt and decrypt.
        """

        crypto_keys_list = self.get_crypto_keys()
        customer_master_key_id = None

        # Create the crypto key only if it doesn't exist
        if crypto_key_alias_name not in crypto_keys_list:
            try:
                self.create_crypto_key(crypto_key_alias_name)

            except Exception as err:
                print("An exception occurred creating new crypto key:\n")
                raise SystemExit(err)
        else:
            # Use crypto keys data under the "Aliases" dict key
            response = self.kms_client.list_aliases().get("Aliases")

            # Trim the "AliasName" string for each key entry by splitting string from the right. [2] to get the just the "AliasName" after the separator
            # For each key entry, compare the string to find a match.
            # eg. response.get("Aliases") returns [{"AliasName": "<alias/AliasName>", "AliasArn": "<AliasArn>", "TargetKeyId": "<TargetKeyId>"}]
            matched_crypto_keys = filter(lambda key: key.get("AliasName").rpartition("/")[2] == crypto_key_alias_name, response)
            
            # Access the "TargetKeyId" property of the first matched key to retrieve the customer_master_key_id associated with it.
            customer_master_key_id = list(matched_crypto_keys)[0].get("TargetKeyId")

            print(f"Using existing crypto key {crypto_key_alias_name}: {customer_master_key_id}\n")

        return customer_master_key_id


def main():
    # Set up argparse
    parser_description = ("Uses a KMS key to encrypt or decrypt secrets in the specified terraform.tfvars."
                          "The script encrypts by default. To decrypt instead, add the -d flag.")

    parser = argparse.ArgumentParser(description = parser_description)

    parser.add_argument("tfvars", help = "specify the path to terraform.tfvars file")
    parser.add_argument("-d", help = "decrypt secrets in terraform.tfvars specified", action = "store_true")

    args = parser.parse_args()

    # Instantiate a Tfvars_Parser to read the terraform.tfvars file
    tfvars_parser = Tfvars_Parser(args.tfvars)
    tfvars_encryptor = None

    # Instantiate a GCP_Tfvars_Encryptor or AWS_Tfvars_Encryptor
    if tfvars_parser.tfvars_data.get("gcp_credentials_file"):
        tfvars_encryptor = GCP_Tfvars_Encryptor(tfvars_parser)

    elif tfvars_parser.tfvars_data.get("aws_credentials_file"):
        tfvars_encryptor = AWS_Tfvars_Encryptor(tfvars_parser)

    # Abort the script if credentials is missing
    else:
        print("Missing gcp_credentials_file or aws_credentials_file in tfvars."
              "Ensure the credentials file is valid and try again.\n")
        raise SystemExit()

    # Encryption is the default, decryption if user specified the -d flag
    if args.d:
        # Abort the decryption if there is not a kms_cryptokey_id (GCP) or customer_master_key_id (AWS) in the tfvars file
        if (not tfvars_parser.tfvars_data.get("kms_cryptokey_id") and
            not tfvars_parser.tfvars_data.get("customer_master_key_id")):
            print("No kms_cryptokey_id or customer_master_key_id present in tfvars. " 
                  "Ensure the secrets are encrypted and try again.\n")
            raise SystemExit()

        tfvars_encryptor.decrypt_tfvars_secrets()
    else:
        # Abort the encryption if there is already a kms_cryptokey_id (GCP) or customer_master_key_id (AWS) present
        if (tfvars_parser.tfvars_data.get("kms_cryptokey_id") or
            tfvars_parser.tfvars_data.get("customer_master_key_id")):
            print("Detected kms_cryptokey_id in tfvars. "
                  "Ensure secrets are not already encrypted and try again.\n")
            raise SystemExit()

        tfvars_encryptor.encrypt_tfvars_secrets()


if __name__ == "__main__":
    main()

