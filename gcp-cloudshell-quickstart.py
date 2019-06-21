# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import googleapiclient.discovery
import json
import os
import subprocess
import shutil
import subprocess
import sys

import cam

SECRETS_DIR = './secrets'
# Service Account ID of the service account to create
SA_ID = 'cloud-access-manager'
SA_ROLES = [
    'roles/editor',
    'roles/cloudkms.cryptoKeyEncrypterDecrypter'
]
PROJECT_ID = os.environ['GOOGLE_CLOUD_PROJECT']
KEY_PATH = SECRETS_DIR + '/' + 'gcp_service_account_key.json'
REQUIRED_APIS = [
    'deploymentmanager.googleapis.com',
    'cloudkms.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'compute.googleapis.com'
]
LINUX_ADMIN_USER = 'cam_admin'

def service_account_find(email):
    service_accounts = iam_service.projects().serviceAccounts().list(
        name = 'projects/{}'.format(PROJECT_ID),
    ).execute()

    if not service_accounts:
        return

    for account in service_accounts['accounts']:
        if account['email'] == email:
            return account
    
    return


def service_account_create(email):
    print('Creating Service Account...')

    service_account = service_account_find(email)
    if service_account:
        print('  Service account {} already exist.'.format(email))
        return service_account

    service_account = iam_service.projects().serviceAccounts().create(
        name = 'projects/' + PROJECT_ID,
        body = {
            'accountId': SA_ID,
            'serviceAccount': {
                'displayName': SA_ID,
                'description': 'Account used by Cloud Access Manager to manage PCoIP workstations.',
            }
        }
    ).execute()

    print('  Created service account: ' + service_account['email'])

    return service_account


def service_account_create_key(service_account, filepath):
    print('Created key for {}...'.format(service_account['email']))

    key = iam_service.projects().serviceAccounts().keys().create(
        name = 'projects/-/serviceAccounts/' + service_account['email'],
        body = {},
    ).execute()

    key_data = base64.b64decode(key['privateKeyData'])

    with open(filepath, 'wb') as keyfile:
        keyfile.write(key_data)

    print('  Key written to ' + filepath)
    return json.loads(key_data.decode('utf-8'))


def iam_policy_update(service_account, roles):

    policy = crm_service.projects().getIamPolicy(
        resource = PROJECT_ID,
    ).execute()

    print('Adding roles:')
    for role in roles:
        print('  {}...'.format(role))
        binding = {
            'role': role,
            'members': ['serviceAccount:{}'.format(service_account['email'])],
        }
        policy['bindings'].append(binding)

    policy = crm_service.projects().setIamPolicy(
        resource = PROJECT_ID,
        body = {
            'policy': policy
        }
    ).execute()

    return policy


def apis_enable(apis):
    print('Enabling APIs:')

    # Using shell command, no Python Google Cloud Client library support
    for api in apis:
        print('  {}...'.format(api))
        subprocess.call(['gcloud', 'services', 'enable', api])

    return


def ssh_key_create(path):
    print('Creating SSH key...')

    # note the space after '-N' is required
    ssh_cmd = 'ssh-keygen -f {} -t rsa -q -N '.format(path)
    subprocess.call(ssh_cmd.split(' '))


if __name__ == '__main__':
    try:
        print('Creating directory {} to store secrets...'.format(SECRETS_DIR))
        os.mkdir(SECRETS_DIR, 0o700)
    except FileExistsError:
        print('Directory {} already exist.'.format(SECRETS_DIR))

    # GCP project setup
    print('Setting GCP project...')

    sa_email = '{}@{}.iam.gserviceaccount.com'.format(SA_ID, PROJECT_ID)
    iam_service = googleapiclient.discovery.build('iam', 'v1')
    crm_service = googleapiclient.discovery.build('cloudresourcemanager', 'v1')

    sa = service_account_create(sa_email)
    iam_policy_update(sa, SA_ROLES)
    sa_key = service_account_create_key(sa, KEY_PATH)
    apis_enable(REQUIRED_APIS)

    print('GCP project setup complete.')

    # Cloud Access Manager setup
    print('Setting Cloud Access Manager...')

    auth_token = input("Paste the auth_token here:").strip()
    reg_code = input("Enter PCoIP Registration Code:").strip()

    mycam = cam.CloudAccessManager(auth_token)
    deployment = mycam.deployment_create('sample_deployment', reg_code)
    mycam.deployment_add_gcp_account(sa_key, deployment)
    connector = mycam.connector_create('sample_connector', deployment)

    print('Cloud Access Manager setup complete.')

    # Terraform preparation
    print('Preparing deployment requirements...')

    ssh_key_create(SECRETS_DIR + '/' + LINUX_ADMIN_USER)

    # update tfvar

    # Don't attempt to install unless needed, since it requires sudo
    if not shutil.which('terraform'):
        rc = subprocess.call(['sudo', 'python3', 'install-terraform.py'])

        if rc:
            print('Error installing Terraform.')
            sys.exit(1)

    # Deploy with Terraform
    print('Deploy with Terraform...')