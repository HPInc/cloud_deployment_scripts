#!/usr/bin/python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import boto3
import os


class Tfvars_Encryptor_AWS:

    def __init__(self):
        """Tfvars_Encryptor_AWS Class Constructor to initialize the object.
        
        """
        self.tfvars_data = { 'aws_credentials_file': '/home/epau/Documents/staging/cloud_deployment_scripts/aws_cred' }

        # Set AWS credentials instance variables from tfvars_data
        self.aws_credentials_file = self.tfvars_data.get("aws_credentials_file")
        
        # Create a client for the KMS API using the provided AWS credentials
        self.aws_credentials = self.initialize_aws_credentials(self.tfvars_data.get('aws_credentials_file'))
        self.kms_client      = boto3.client('kms', aws_access_key_id = self.aws_credentials.get('aws_access_key_id'),
                                               aws_secret_access_key = self.aws_credentials.get('aws_access_key_id'))

        # AWS KMS resource variables
        self.crypto_key_id = self.initialize_cryptokey("cas_key")


    def create_crypto_key(self, crypto_key_alias):
        """A method to create a crypto key on AWS KMS.
        
        Args:
            crypto_key_alias (str): the alias name of the crypto key to be created
        Returns:
            string: customer_master_key_id used for the tfvars
        """
        # Use KMS client to create key and store the returned KeyId
        customer_master_key_id = self.kms_client.create_key().get('KeyMetadata').get('KeyId')
        
        # Give this KeyId an alias name
        self.kms_client.create_alias(
            # The alias to create. Aliases must begin with 'alias/'.
            AliasName = 'alias/{}'.format(crypto_key_alias_name),
            TargetKeyId = crypto_key_id
        )
        
        print("Created {}: {}\n".format(crypto_key_alias_name, customer_master_key_id))

        return customer_master_key_id


    def initialize_aws_credentials(self, path):
        """A method that parses the aws_access_key_id and aws_secret_access_key 
        from aws_credentials_file required for the KMS client.

        This initialization method is used in the constructor to
        initialize both the aws_access_key_id and aws_secret_access_key 
        by parsing the aws_credentials_file. 
        
        Args:
            path (str): path to aws_credentials_file
        """

        aws_access_key_id = None
        aws_secret_access_key = None

        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Skip blank lines and comment lines
                # "not line" must come first using short circuiting to avoid string index out of range error
                if not line or line[0] in ("#"):
                    continue

                if 'aws_secret_access_key' in line:
                    self.aws_secret_access_key = line.rpartition('=')[2].strip()
                    continue

                if 'aws_access_key_id' in line:
                    self.aws_access_key_id = line.rpartition('=')[2].strip()
                    continue
        
        return {    'aws_access_key_id': aws_access_key_id, 
                'aws_secret_access_key': aws_secret_access_key }


    def initialize_cryptokey(self, crypto_key_alias_name):
        """A method that initializes this instance's crypto key.

        This initialization method is called in the constructor to
        create a default crypto key if it doesn't exist. If the key
        exists already, then reuse it for this instance.
        
        Args:
            crypto_key_id (str): crypto key used to encrypt and decrypt
        Returns:
            string: the crypto key used
        """

        crypto_keys_list = self.get_crypto_keys()
        crypto_key_id = None

        # Create the crypto key only if it doesn't exist
        if crypto_key_alias_name not in crypto_keys_list:
            try:
                self.create_crypto_key(crypto_key_alias_name)

            except Exception as err:
                print("An exception occurred creating new crypto key:")
                print("{}".format(err))
                raise SystemExit()
        else:
            # Use crypto keys data under the 'Aliases' dict key
            response = self.kms_client.list_aliases().get('Aliases')

            # Trim the 'AliasName' string for each key entry by splitting string from the right. [2] to get the just the 'AliasName' after the separator
            # For each key entry, compare the string to find a match.
            # eg. response.get('Aliases') returns [{'AliasName': '<alias/AliasName>', 'AliasArn': '<AliasArn>', 'TargetKeyId': '<TargetKeyId>'}]
            matched_crypto_keys = filter(lambda key: key.get('AliasName').rpartition('/')[2] == crypto_key_alias_name, response)
            
            # Access the 'TargetKeyId' property of the first matched key to retrieve the crypto_key_id associated with it.
            crypto_key_id = list(matched_crypto_keys)[0].get('TargetKeyId')

            print("Using existing crypto key {}: {}\n".format(crypto_key_alias_name, crypto_key_id))
        
        return crypto_key_id


    def get_crypto_keys(self):
        """A method that retrieves a list of crypto keys aliase names associated with the AWS credentials in the region.

        This method returns a list of all the crypto keys aliase names associated with the AWS credentials in the region.
        
        Returns:
            list: a list of all the crypto keys aliase names associated with the AWS credentials in the region.
        """

        # Use crypto keys data under the 'Aliases' dict key
        response = self.kms_client.list_aliases().get('Aliases')

        # Access the 'AliasName' property for each key entry by splitting string from the right. [2] to get the string after the separator
        # eg. response.get('Aliases') returns [{'AliasName': '<alias/AliasName>', 'AliasArn': '<AliasArn>', 'TargetKeyId': '<TargetKeyId>'}]
        crypto_keys_list = list(map(lambda key: key.get('AliasName').rpartition('/')[2], response))

        return crypto_keys_list


    def encrypt_plaintext(self, plaintext):
        """A method that encrypts plaintext.

        Uses AWS KMS to encrypt plaintext to ciphertext using the provided
        symmetric crypto key that belongs to this instance.
        
        Args:
            plaintext (str): the plainttext being encrypted
        Returns:
            string: the ciphertext
        """

        # Use the KMS API to encrypt the data.
        response = self.kms_client.encrypt(
                        KeyId = self.crypto_key_id, 
                        Plaintext = plaintext.encode("utf-8")
                    )

        # Base64 encoding of ciphertext
        ciphertext = base64.b64encode(response.get('CiphertextBlob')).decode("utf-8")
        
        return ciphertext


    def decrypt_ciphertext(self, ciphertext):
        """A method that decrypts ciphertext.

        Uses AWS KMS to decrypt ciphertext back to plaintext using the provided
        symmetric crypto key that belongs to this instance.
        
        Args:
            ciphertext (str): the ciphertext being decrypted
        Returns:
            string: the plaintext
        """

        # Convert ciphertext string to a byte string, then Base64 decode it
        ciphertext = base64.b64decode(ciphertext.encode("utf-8"))

        # Use the KMS API to decrypt the data
        response = self.kms_client.decrypt(
                        KeyId = self.crypto_key_id,
                        CiphertextBlob = ciphertext
                    )

        # Decode Base64 plaintext
        plaintext = response.get('Plaintext').decode("utf-8")

        return plaintext


def main():
    encryptor = Tfvars_Encryptor_AWS()

    ciphertext = encryptor.encrypt_plaintext('hello')
    print(ciphertext)

    plaintext = encryptor.decrypt_ciphertext(ciphertext)
    print(plaintext)


if __name__ == '__main__':
    main()
