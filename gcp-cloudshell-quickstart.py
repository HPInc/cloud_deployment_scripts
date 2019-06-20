# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import googleapiclient.discovery
import os
import subprocess
import shutil
import subprocess
import sys

# Service Account ID of the service account to create
SA_ID = 'cloud-access-manager'
SA_ROLES = [
    'roles/editor',
    'roles/cloudkms.cryptoKeyEncrypterDecrypter'
]
PROJECT_ID = os.environ['GOOGLE_CLOUD_PROJECT']
KEY_PATH = './key.json'
REQUIRED_APIS = [
    'deploymentmanager.googleapis.com',
    'cloudkms.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'compute.googleapis.com'
]

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

    with open(filepath, 'wb') as keyfile:
        keyfile.write(base64.b64decode(key['privateKeyData']))

    print('  Key written to ' + filepath)
    return


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


if __name__ == '__main__':
    # Don't attempt to install unless needed, since it requires sudo
    if not shutil.which('terraform'):
        rc = subprocess.call(['sudo', 'python3', 'install-terraform.py'])

        if rc:
            print('Error installing Terraform.')
            sys.exit(1)

    sa_email = '{}@{}.iam.gserviceaccount.com'.format(SA_ID, PROJECT_ID)
    iam_service = googleapiclient.discovery.build('iam', 'v1')
    crm_service = googleapiclient.discovery.build('cloudresourcemanager', 'v1')

    sa = service_account_create(sa_email)
    iam_policy_update(sa, SA_ROLES)
    service_account_create_key(sa, KEY_PATH)
    apis_enable(REQUIRED_APIS)
