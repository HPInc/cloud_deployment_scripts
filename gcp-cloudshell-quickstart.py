# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import datetime
import fileinput
import getpass
import googleapiclient.discovery
import json
import os
import shutil
import subprocess
import sys

import cam

# Service Account ID of the service account to create
SA_ID       = 'cloud-access-manager'
SA_ROLES    = [
    'roles/editor',
    'roles/cloudkms.cryptoKeyEncrypterDecrypter'
]

PROJECT_ID = os.environ['GOOGLE_CLOUD_PROJECT']
REQUIRED_APIS = [
    'deploymentmanager.googleapis.com',
    'cloudkms.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'compute.googleapis.com'
]

iso_time = datetime.datetime.now().isoformat()
DEPLOYMENT_NAME = 'sample_deployment_' + iso_time
CONNECTOR_NAME  = 'sample_connector_' + iso_time

# All paths are relative to the deployment directory, DEPLOYMENT_PATH
DEPLOYMENT_PATH  = 'deployments/gcp/dc-cac-ws'
TF_VARS_REF_PATH = 'terraform.tfvars.sample'
TF_VARS_PATH     = 'terraform.tfvars'
SECRETS_DIR      = 'secrets'
SA_KEY_PATH      = SECRETS_DIR + '/gcp_service_account_key.json'
SSH_KEY_PATH     = SECRETS_DIR + '/cam_admin_id_rsa'


def service_account_find(email):
    service_accounts = iam_service.projects().serviceAccounts().list(
        name = 'projects/{}'.format(PROJECT_ID),
    ).execute()

    if not service_accounts:
        return

    for account in service_accounts['accounts']:
        if account['email'] == email:
            return account


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


def ssh_key_create(path):
    print('Creating SSH key...')

    # note the space after '-N' is required
    ssh_cmd = 'ssh-keygen -f {} -t rsa -q -N '.format(path)
    subprocess.call(ssh_cmd.split(' '))


# Creates a new .tfvar based on the .tfvar.sample file
def tf_vars_create(ref_file_path, tfvar_file_path, settings):

    if os.path.exists(tfvar_file_path):
        overwrite = input("Found an existing .tfvar file, overwrite (y/N)?").strip().lower()
        if overwrite not in ('y', 'yes'):
            print('{} already exist. Exiting...'.format(tfvar_file_path))
            sys.exit(1)

    with open(ref_file_path, 'r') as ref_file, open(tfvar_file_path, 'w') as out_file:
        for line in ref_file:
            # Comments and blank lines are unchanged
            if line[0] in ('#', '\n'):
                out_file.write(line)
                continue

            key = line.split('=')[0].strip()
            try:
                out_file.write('{} = "{}"\n'.format(key, settings[key]))
            except KeyError:
                # Remove file and error out
                os.remove(tfvar_file_path)
                print('Required value for {} missing. tfvars file {} not created.'.format(key, tfvar_file_path))
                sys.exit(1)


def terraform_install():
    # Don't attempt to install unless needed, since it requires sudo
    if not shutil.which('terraform'):
        install_cmd = 'sudo python3 install-terraform.py'
        rc = subprocess.call(install_cmd.split(' '))

        if rc:
            print('Error installing Terraform.')
            sys.exit(1)


if __name__ == '__main__':
    terraform_install()

    os.chdir(DEPLOYMENT_PATH)

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
    sa_key = service_account_create_key(sa, SA_KEY_PATH)
    apis_enable(REQUIRED_APIS)

    print('GCP project setup complete.')

    # Cloud Access Manager setup
    print('Setting Cloud Access Manager...')

    auth_token = input("Paste the auth_token here:").strip()
    reg_code = input("Enter PCoIP Registration Code:").strip()

    mycam = cam.CloudAccessManager(auth_token)
    deployment = mycam.deployment_create(DEPLOYMENT_NAME, reg_code)
    mycam.deployment_add_gcp_account(sa_key, deployment)
    connector = mycam.connector_create(CONNECTOR_NAME, deployment)

    print('Cloud Access Manager setup complete.')

    # Terraform preparation
    print('Preparing deployment requirements...')

    ssh_key_create(SSH_KEY_PATH)

    password = getpass.getpass("Enter password for Active Directory:").strip()

    #TODO: refactor this to work with more types of deployments
    settings = {
        'gcp_credentials_file':           SA_KEY_PATH,
        'gcp_project_id':                 PROJECT_ID,
        'dc_admin_password':              password,
        'safe_mode_admin_password':       password,
        'service_account_password':       password,
        'cac_admin_ssh_pub_key_file':     SSH_KEY_PATH + '.pub',
        'cac_admin_ssh_priv_key_file':    SSH_KEY_PATH,
        'win_gfx_instance_count':         0,
        'centos_gfx_instance_count':      0,
        'centos_std_instance_count':      0,
        'centos_admin_ssh_pub_key_file':  SSH_KEY_PATH + '.pub',
        'centos_admin_ssh_priv_key_file': SSH_KEY_PATH,
        'pcoip_registration_code':        reg_code,
        'cac_token':                      connector['token'],
    }

    # update tfvar
    tf_vars_create(TF_VARS_REF_PATH, TF_VARS_PATH, settings)

    # Deploy with Terraform
    print('Deploy with Terraform...')

    tf_cmd = 'terraform init'
    subprocess.call(tf_cmd.split(' '))

    tf_cmd = 'terraform apply -auto-approve'
    subprocess.call(tf_cmd.split(' '))
