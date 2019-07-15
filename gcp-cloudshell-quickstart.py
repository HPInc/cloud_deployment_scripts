#!/usr/bin/python3

# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import datetime
import getpass
import googleapiclient.discovery
import json
import os
import shutil
import subprocess
import sys
import time

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
    'compute.googleapis.com',
    'dns.googleapis.com',
]

iso_time = datetime.datetime.now().isoformat()
DEPLOYMENT_NAME = 'sample_deployment_' + iso_time
CONNECTOR_NAME  = 'sample_connector_' + iso_time

# User entitled to workstations
ENTITLE_USER = 'Administrator'

CFG_FILE_PATH    = 'gcp-cloudshell-quickstart.cfg'
DEPLOYMENT_PATH  = 'deployments/gcp/dc-cac-ws'
# All of the following paths are relative to the deployment directory, DEPLOYMENT_PATH
TF_VARS_REF_PATH = 'terraform.tfvars.sample'
TF_VARS_PATH     = 'terraform.tfvars'
SECRETS_DIR      = 'secrets'
SA_KEY_PATH      = SECRETS_DIR + '/gcp_service_account_key.json'
SSH_KEY_PATH     = SECRETS_DIR + '/cam_admin_id_rsa'

# Types of workstations
WS_TYPES = ['scent', 'gcent', 'gwin']

def check_requirements():
    if not PROJECT_ID:
        print('The PROJECT property has not been set.')
        print('Please run "gcloud config set project [PROJECT_ID]" to set the project.')
        print('See: https://cloud.google.com/sdk/gcloud/reference/config/set')
        print('')
        sys.exit(1)


def quickstart_config_read(cfg_file):
    cfg_data = {}

    with open(cfg_file, 'r') as f:
        for line in f:
            if line[0] in ('#', '\n'):
                continue

            key, value = map(str.strip, line.split(':'))
            cfg_data[key] = value

    return cfg_data


def ad_password_get():
    txt = r'''
    Please enter a password for the Active Directory Administrator.

    Note Windows password complexity requirements:
    1. Must not contain user's account name or display name
    2. Must have 3 of the following categories:
       - A-Z
       - a-z
       - 0-9
       - special characters: (~!@#$%^&*_-+=`|\(){}[]:;"'<>,.?/)
       - unicode characters

    See: https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
    '''
    print(txt)
    while True:
        password1 = getpass.getpass('Enter a password: ').strip()
        password2 = getpass.getpass('Re-enter the password: ').strip()

        if password1 == password2:
            print('')
            break

        print('The passwords do not match.  Please try again.')

    return password1


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
        body = {},
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
        subprocess.run(['gcloud', 'services', 'enable', api], check=True)


def ssh_key_create(path):
    print('Creating SSH key...')

    # note the space after '-N' is required
    ssh_cmd = 'ssh-keygen -f {} -t rsa -q -N '.format(path)
    subprocess.run(ssh_cmd.split(' '), check=True)


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
        subprocess.run(install_cmd.split(' '), check=True)


if __name__ == '__main__':
    check_requirements()

    cfg_data = quickstart_config_read(CFG_FILE_PATH)

    password = ad_password_get()

    print('Preparing local requirements...')
    terraform_install()
    os.chdir(DEPLOYMENT_PATH)

    try:
        print('Creating directory {} to store secrets...'.format(SECRETS_DIR))
        os.mkdir(SECRETS_DIR, 0o700)
    except FileExistsError:
        print('Directory {} already exist.'.format(SECRETS_DIR))

    ssh_key_create(SSH_KEY_PATH)

    print('Local requirements setup complete.\n')

    print('Setting GCP project...')
    sa_email = '{}@{}.iam.gserviceaccount.com'.format(SA_ID, PROJECT_ID)
    iam_service = googleapiclient.discovery.build('iam', 'v1')
    crm_service = googleapiclient.discovery.build('cloudresourcemanager', 'v1')

    sa = service_account_create(sa_email)
    iam_policy_update(sa, SA_ROLES)
    sa_key = service_account_create_key(sa, SA_KEY_PATH)
    apis_enable(REQUIRED_APIS)

    print('GCP project setup complete.\n')

    print('Setting Cloud Access Manager...')
    mycam = cam.CloudAccessManager(cfg_data.get('api_token'))

    print('Creating deployment {}...'.format(DEPLOYMENT_NAME))
    deployment = mycam.deployment_create(DEPLOYMENT_NAME, cfg_data.get('reg_code'))
    mycam.deployment_add_gcp_account(sa_key, deployment)

    print('Creating connector {}...'.format(CONNECTOR_NAME))
    connector = mycam.connector_create(CONNECTOR_NAME, deployment)

    print('Cloud Access Manager setup complete.\n')

    print('Deploying with Terraform...')
    #TODO: refactor this to work with more types of deployments
    settings = {
        'gcp_credentials_file':           SA_KEY_PATH,
        'gcp_project_id':                 PROJECT_ID,
        'dc_admin_password':              password,
        'safe_mode_admin_password':       password,
        'service_account_password':       password,
        'cac_admin_ssh_pub_key_file':     SSH_KEY_PATH + '.pub',
        'cac_admin_ssh_priv_key_file':    SSH_KEY_PATH,
        'win_gfx_instance_count':         cfg_data.get('gwin'),
        'centos_gfx_instance_count':      cfg_data.get('gcent'),
        'centos_std_instance_count':      cfg_data.get('scent'),
        'centos_admin_ssh_pub_key_file':  SSH_KEY_PATH + '.pub',
        'centos_admin_ssh_priv_key_file': SSH_KEY_PATH,
        'pcoip_registration_code':        cfg_data.get('reg_code'),
        'cac_token':                      connector['token'],
    }

    # update tfvar
    tf_vars_create(TF_VARS_REF_PATH, TF_VARS_PATH, settings)

    tf_cmd = 'terraform init'
    subprocess.run(tf_cmd.split(' '), check=True)

    tf_cmd = 'terraform apply -auto-approve'
    subprocess.run(tf_cmd.split(' '), check=True)

    comp_proc = subprocess.run(['terraform','output','cac-public-ip'],
                               check=True,
                               stdout=subprocess.PIPE)
    cac_public_ip = comp_proc.stdout.decode().split('"')[1]

    print('Terraform deployment complete.\n')

    # Add existing workstations
    for t in WS_TYPES:
        for i in range(int(cfg_data.get(t))):
            hostname = '{}-{}'.format(t, i)
            print('Adding "{}" to Cloud Access Manager...'.format(hostname))
            mycam.machine_add_existing(
                hostname,
                PROJECT_ID,
                'us-west2-b',
                deployment
            )

    # Loop until Administrator user is found in CAM
    while True:
        entitle_user = mycam.user_get(ENTITLE_USER, deployment)
        if entitle_user:
            break

        print('Waiting for user "{}" to be synced. Retrying in 10 seconds...'
              .format(ENTITLE_USER))
        time.sleep(10)

    # Add entitlements for each workstation
    machines_list = mycam.machines_get(deployment)
    for machine in machines_list:
        print(
            'Assigning workstation "{}" to user "{}"...'
            .format(machine['machineName'], ENTITLE_USER)
        )
        mycam.entitlement_add(entitle_user, machine)

    print('\nQuickstart deployment finished.\n')

    print('Next steps:')
    print('- Connect to a workstation:')
    print('  From a PCoIP client, connect to the Cloud Access Connector ({}) and sign in with the "{}" user credentials.'.format(cac_public_ip, ENTITLE_USER))
    print('- Clean up:')
    print('  To delete this deployment, go to the {} directory and run "terraform destroy".'.format(DEPLOYMENT_PATH))
