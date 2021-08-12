#!/usr/bin/env python3

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# This script initializes Hashicorp Vault for use with Teradici CAS Manager. It
# expects Vault to be already running with "awskms" auto-unsealing configured
# and is uninitialized. This script performs the following:
# 1- initializes Vault (no unzealing required due to awskms auto-unsealing)
# 2- saves root token and recovery keys in AWS Secrets Manager
# 3- sets up secrets engine and path for CAS Manager
# 4- creates policy, token role, and a renewable token for CAS Manager
# 5- saves the token for CAS Manager in AWS Secrets Manager

import argparse
import boto3
from   botocore.exceptions import ClientError
import hvac
import json
import time

VAULT_URL    = "http://localhost:8200"
POLICY_NAME  = "casm-policy"
ROLE_NAME    = "casm-role"
TOKEN_PERIOD = "24h"

def aws_secret_put(region, secret_name, value):
    session = boto3.session.Session()
    sec_mgr_client = session.client(
        service_name='secretsmanager',
        region_name=region,
    )

    sec_mgr_client.put_secret_value(SecretId=secret_name, SecretString=value)

parser = argparse.ArgumentParser(description="This script provisions a Hashicorp vault AWS EC2 instance for use with CAS Manager.")

parser.add_argument("--cas_manager_vault_token_id",
                    help="AWS Secrets Manager secret ID to store token for CAS Manager.")
parser.add_argument("--region",
                    help="AWS region to put secrets in.")
parser.add_argument("--vault_initialization_keys_id",
                    help="AWS Secrets Manager secret ID to store Vault Initialization Keys and Root Token.")
parser.add_argument("--vault_recovery_shares",
                    type=int,
                    default=1,
                    help="Number of shares to split the Vault recovery key into.")
parser.add_argument("--vault_recovery_threshold",
                    type=int,
                    default=1,
                    help="Number of shares required to reconstruct the Vault recovery key.")

args = parser.parse_args()

vault_client = hvac.Client(url=VAULT_URL)

if vault_client.sys.is_initialized():
  print("Vault is already initialized, exiting...")
  raise SystemExit

print("Initializing Vault...")
result = vault_client.sys.initialize(
  recovery_shares=args.vault_recovery_shares,
  recovery_threshold=args.vault_recovery_threshold)
root_token = result['root_token']

print("Saving root token and recovery keys to AWS Secrets Manager...")
aws_secret_put(args.region,
               args.vault_initialization_keys_id,
               json.dumps(result))

print("Setting up Vault for CAS Manager...")
vault_client = hvac.Client(url=VAULT_URL, token=root_token)

time.sleep(5)

print("Enabling 'secret/' path...")
vault_client.sys.enable_secrets_engine('kv', path='secret/')

print("Creating policy for CAS Manager...")
policy = """
path "secret/data/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
"""
vault_client.sys.create_or_update_policy(name=POLICY_NAME, policy=policy)

print("Creating new role for CAS Manager...")  
vault_client.auth.token.create_or_update_role(role_name=ROLE_NAME,
                                              allowed_policies=[POLICY_NAME])

print("Create CAS Manager Token")
resp = vault_client.auth.token.create(role_name=ROLE_NAME,
                                      no_parent=True,
                                      policies=[POLICY_NAME],
                                      renewable=True,
                                      period=TOKEN_PERIOD)
secret = {'Token': resp['auth']['client_token']}

print("Saving CAS Manager token to AWS Secrets Manager...")
aws_secret_put(args.region,
               args.cas_manager_vault_token_id,
               json.dumps(secret))

print("Vault Provisioning finished.")
