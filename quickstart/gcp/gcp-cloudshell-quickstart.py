#!/usr/bin/env python3

# Copyright Teradici Corporation 2019-2022;  © Copyright 2022 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import base64
import datetime
import importlib
import json
import os
import re
import shutil
import site
import subprocess
import sys
import textwrap
import time

import awm
import interactive

REQUIRED_PACKAGES = {
    'google-api-python-client': None,
    'grpc-google-iam-v1': None,
    'google-cloud-kms': "2.0.0"
}

# Service Account ID of the service account to create
SA_ID    = 'anyware-manager'
SA_ROLES = [
    'roles/editor',
    'roles/cloudkms.cryptoKeyEncrypterDecrypter',
    'roles/logging.configWriter'
]

PROJECT_ID    = os.environ['GOOGLE_CLOUD_PROJECT']
REQUIRED_APIS = [
    'deploymentmanager.googleapis.com',
    'cloudkms.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'compute.googleapis.com',
    'dns.googleapis.com',
    'iam.googleapis.com',
    'iap.googleapis.com',
    'logging.googleapis.com',
    'monitoring.googleapis.com',
]

iso_time        = datetime.datetime.utcnow().isoformat(timespec='seconds').replace(':','').replace('-','') + 'Z'
DEPLOYMENT_NAME = 'quickstart_deployment_' + iso_time
CONNECTOR_NAME  = 'quickstart_awc_' + iso_time

# User entitled to workstations
ENTITLE_USER = 'Administrator'

HOME               = os.path.expanduser('~')
TERRAFORM_BIN_DIR  = f'{HOME}/bin'
TERRAFORM_BIN_PATH = TERRAFORM_BIN_DIR + '/terraform'
TERRAFORM_VER_PATH = 'deployments/gcp/single-connector/versions.tf'
CFG_FILE_PATH      = 'gcp-cloudshell-quickstart.cfg'
DEPLOYMENT_PATH    = 'deployments/gcp/single-connector'

# All of the following paths are relative to the deployment directory, DEPLOYMENT_PATH
TF_VARS_REF_PATH           = 'terraform.tfvars.sample'
TF_VARS_PATH               = 'terraform.tfvars'
SECRETS_DIR                = 'secrets'
GCP_SA_KEY_PATH            = SECRETS_DIR + '/gcp_service_account_key.json'
SSH_KEY_PATH               = SECRETS_DIR + '/awm_admin_id_rsa'
AWM_DEPLOYMENT_SA_KEY_PATH = SECRETS_DIR + '/awm_deployment_sa_key.json.encrypted'

# Types of workstations
WS_TYPES = ['scent', 'gcent', 'swin', 'gwin']

def ensure_requirements():
    if not PROJECT_ID:
        print('The PROJECT property has not been set.')
        print('Please run "gcloud config set project [PROJECT_ID]" to set the project.')
        print('See: https://cloud.google.com/sdk/gcloud/reference/config/set')
        print('')
        sys.exit(1)

    ensure_required_packages()
    import_modules()
    ensure_terraform()


def ensure_required_packages():
    """A function that ensures the correct version of Python packages are installed. 

    The function first checks if the required packages are installed. If a package is 
    installed, the required version number will then be checked. It will next prompt 
    the user to update or install the required packages.
    """

    packages_to_install_list = []

    for package, required_version in REQUIRED_PACKAGES.items():
        check_cmd = f'{sys.executable} -m pip show {package}'
        output = subprocess.run(check_cmd.split(' '), stdout=subprocess.PIPE).stdout.decode('utf-8')

        # If a package is not found, skip version checking and simply install the latest package
        if not output:
            packages_to_install_list.append(package)

        elif required_version is not None:
            # Second line outputs the version of the specified package
            current_version = output.splitlines()[1].split(' ')[-1]

            # Convert the string into a tuple of numbers for comparison
            current_version_tuple  = tuple( map(int, current_version.split('.')) )
            required_version_tuple = tuple( map(int, required_version.split('.')) )

            if current_version_tuple < required_version_tuple:
                packages_to_install_list.append(package)

    if packages_to_install_list:
        # Convert the list to a string of packages delimited by a space
        packages_to_install = " ".join(packages_to_install_list)
        install_cmd = f'{sys.executable} -m pip install --upgrade {packages_to_install} --user'

        install_permission = input(
            'One or more of the following Python packages are outdated or missing:\n'
            f'  {packages_to_install}\n\n'
            'The script can install these packages in the user\'s home directory using the following command:\n' 
            f'  {install_cmd}\n'
            'Proceed? (y/n)? ').strip().lower()

        if install_permission not in ('y', 'yes'):
            print('Python packages are required for deployment. Exiting...')
            sys.exit(1)

        subprocess.check_call(install_cmd.split(' '))

        # Refresh sys.path to detect new modules in user's home directory.
        importlib.reload(site)


def import_modules():
    """A function that dynamically imports required Python packages.
    """

    # Global calls for import statements are required to avoid module not found error
    import_required_packages = '''\
    import googleapiclient.discovery
    from google.cloud import kms
    from google.api_core import exceptions as google_exc
    '''

    # Recommended to clear cache after installing python packages for dynamic imports
    importlib.invalidate_caches()

    exec(textwrap.dedent(import_required_packages), globals())
    print('Successfully imported required Python packages.')


def ensure_terraform():
    """A function that ensures the required Terraform version is installed. 

    The function first checks if the required Terraform version is installed in 
    the user's system. If Terraform is not installed, it will prompt the user to 
    install Terraform in the user's home directory. 
    """

    global TERRAFORM_BIN_PATH

    path = shutil.which('terraform')

    # Reference versions.tf file for the required version
    with open(f"../../{TERRAFORM_VER_PATH}","r") as f:
        data = f.read()

    required_version = re.search(r'\">=\s([\d.]+)\"', data).group(1)

    if path:
        cmd = 'terraform -v'
        # Run the command 'terraform -v' and use the first line as the Terraform version
        terraform_version = subprocess.run(cmd.split(' '),  stdout=subprocess.PIPE).stdout.decode('utf-8').splitlines()[0]
        print(f'Found {terraform_version} in {path}.')

        # Use regex to parse the version number from string (i.e. 0.12.18)
        current_version = re.search(r'Terraform\s*v([\d.]+)', terraform_version).group(1)

        # Convert the string into a tuple of numbers for comparison
        current_version_tuple  = tuple( map(int, current_version.split('.')) )
        required_version_tuple = tuple( map(int, required_version.split('.')) )

        if current_version_tuple >= required_version_tuple:
            TERRAFORM_BIN_PATH = path
            return

    install_permission = input(
        f'This system is missing Terraform version >= {required_version}.\n'
        f'Proceed to download and install Terraform in {TERRAFORM_BIN_DIR} (y/n)? ').strip().lower()

    if install_permission not in ('y', 'yes'):
        print('Terraform is required for deployment. Exiting...')
        sys.exit(1)

    install_cmd = f'{sys.executable} ../../tools/install-terraform.py {TERRAFORM_BIN_DIR}'
    subprocess.run(install_cmd.split(' '), check=True)


def quickstart_config_read(cfg_file):
    cfg_data = {}

    with open(cfg_file, 'r') as f:
        for line in f:
            if line[0] in ('#', '\n'):
                continue

            key, value = map(str.strip, line.split(':'))
            cfg_data[key] = value

    return cfg_data


def service_account_find(email):
    service_accounts = iam_service.projects().serviceAccounts().list(
        name = f'projects/{PROJECT_ID}',
    ).execute()

    if not service_accounts:
        return

    for account in service_accounts['accounts']:
        if account['email'] == email:
            return account


def service_account_create(project_id, sa_id, prefix):
    print('Creating Service Account...')
    account_id = f'{prefix}-{sa_id}'
    sa_email = f'{account_id}@{project_id}.iam.gserviceaccount.com'

    service_account = service_account_find(sa_email)
    if service_account:
        print(f'  Service account {sa_email} already exists.')
        # The service account limit check is placed here so that the script doesn't
        # unfortunately exit after the user enters their configurations if error, but
        # the key will be created later to avoid reaching the limit, in case
        # something goes wrong and the script exits before the key is used.
        service_account_create_key_limit_check(service_account)
        return service_account

    service_account = iam_service.projects().serviceAccounts().create(
        name = 'projects/' + project_id,
        body = {
            'accountId': account_id,
            'serviceAccount': {
                'displayName': account_id,
                'description': 'Account used by Anyware Manager to manage PCoIP workstations.',
            }
        }
    ).execute()

    print('  Created service account: ' + service_account['email'])

    return service_account


def service_account_create_key(service_account, filepath):
    print(f'Created key for {service_account["email"]}...')
    key = iam_service.projects().serviceAccounts().keys().create(
        name = 'projects/-/serviceAccounts/' + service_account['email'],
        body = {},
    ).execute()

    key_data = base64.b64decode(key['privateKeyData'])

    with open(filepath, 'wb') as keyfile:
        keyfile.write(key_data)

    print('  Key written to ' + filepath)
    return json.loads(key_data.decode('utf-8'))


def service_account_create_key_limit_check(service_account):
    print(f'  Checking number of keys owned by {service_account["email"]}... ', end='')
    keys = iam_service.projects().serviceAccounts().keys().list(
        name='projects/-/serviceAccounts/' + service_account['email']
    ).execute()['keys']
    user_managed_keys = list(filter(lambda k: (k['keyType'] == 'USER_MANAGED'), keys)) 
    print(f'{len(user_managed_keys)}/10')
    if len(user_managed_keys) >= 10:
        print(f'    ERROR: The service account has reached the limit of the number of keys it can create.',
        '    Please see: https://cloud.google.com/iam/docs/creating-managing-service-account-keys',
        'Exiting script...', sep='\n')
        sys.exit(1)


def iam_policy_update(service_account, roles):

    policy = crm_service.projects().getIamPolicy(
        resource = PROJECT_ID,
        body = {},
    ).execute()

    print('Adding roles:')
    for role in roles:
        print(f'  {role}...')
        binding = {
            'role': role,
            'members': [f'serviceAccount:{service_account["email"]}'],
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
        print(f'  {api}...')
        subprocess.run(['gcloud', 'services', 'enable', api], check=True)

def disable_default_sink():
    subprocess.run(['gcloud', 'logging', 'sinks', 'update', '_Default', '--disabled'], check=True)

def ssh_key_create(path):
    print('Creating SSH key...')

    # note the space after '-N' is required
    ssh_cmd = f'ssh-keygen -f {path} -t rsa -q -N '
    subprocess.run(ssh_cmd.split(' '), check=True)


# Creates a new .tfvar based on the .tfvar.sample file
def tf_vars_create(ref_file_path, tfvar_file_path, settings):

    if os.path.exists(tfvar_file_path):
        overwrite = input("Found an existing .tfvar file, overwrite (y/n)? ").strip().lower()
        if overwrite not in ('y', 'yes'):
            print(f'{tfvar_file_path} already exists. Exiting...')
            sys.exit(1)

    with open(ref_file_path, 'r') as ref_file, open(tfvar_file_path, 'w') as out_file:
        for line in ref_file:
            if line[0] == '#':
                # Check if it's an optional variable and uncomment if so
                for k in settings.keys():
                    # Building string using + because can't use f"{k}" with regex
                    pattern = "^#\s*(" + k + ")\s*="
                    if re.search(pattern, line.strip()):
                        line = f'{k} = "{settings[k]}"\n'
            elif line[0] != '\n':
                key = line.split('=')[0].strip()
                line = f'{key} = "{settings[key]}"\n'

            out_file.write(line)


if __name__ == '__main__':
    ensure_requirements()

    apis_enable(REQUIRED_APIS)

    # The _Default sink save VM instance logs to _Default log bucket. We disable
    # the _Default sink to avoid having duplicated VM instance logs in the log
    # bucket created by Terraform and _Default log bucket.
    disable_default_sink()

    cfg_data = interactive.configurations_get(PROJECT_ID, WS_TYPES, ENTITLE_USER)

    print('Setting GCP project...')
    iam_service = googleapiclient.discovery.build('iam', 'v1')
    crm_service = googleapiclient.discovery.build('cloudresourcemanager', 'v1')

    prefix = cfg_data.get('prefix')

    sa = service_account_create(PROJECT_ID, SA_ID, prefix)
    iam_policy_update(sa, SA_ROLES)

    print('GCP project setup complete.\n')

    print('Preparing local requirements...')
    os.chdir(f"../../{DEPLOYMENT_PATH}")
    # Paths passed into terraform.tfvars should be absolute paths
    cwd = os.getcwd() + '/'

    try:
        print(f'Creating directory {SECRETS_DIR} to store secrets...')
        os.mkdir(SECRETS_DIR, 0o700)
    except FileExistsError:
        print(f'Directory {SECRETS_DIR} already exists.')

    ssh_key_create(SSH_KEY_PATH)

    print('Local requirements setup complete.\n')

    print('Setting Anyware Manager...')
    my_awm = awm.AnywareManager(cfg_data.get('api_token'))
    # TODO: Add a proper clean up of GCP IAM resources so we don't have to move the
    # service account creation to here after the rest of the GCP setup
    sa_key = service_account_create_key(sa, GCP_SA_KEY_PATH)

    print(f'Creating deployment {DEPLOYMENT_NAME}...')
    deployment = my_awm.deployment_create(DEPLOYMENT_NAME, cfg_data.get('reg_code'))
    my_awm.deployment_add_gcp_account(sa_key, deployment)

    print('Creating Anyware Manager API key...')
    awm_deployment_key = my_awm.deployment_key_create(deployment)

    print('Anyware Manager setup complete.\n')

    print('Encrypting secrets...')
    days90 = 7776000

    kms_client = kms.KeyManagementServiceClient()

    parent = f"projects/{PROJECT_ID}/locations/{cfg_data.get('gcp_region')}"
    key_ring_id = 'cloud_deployment_scripts'
    key_ring_init = {}

    try:
        key_ring = kms_client.create_key_ring(request={'parent': parent, 'key_ring_id': key_ring_id, 'key_ring': key_ring_init})
        print(f'Created Key Ring {key_ring.name}')
    except google_exc.AlreadyExists:
        print(f'Key Ring {key_ring_id} already exists. Using it...')

    parent = kms_client.key_ring_path(PROJECT_ID, cfg_data.get('gcp_region'), key_ring_id)
    crypto_key_id = 'quickstart_key'
    crypto_key_init = {
        'purpose': kms.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT,
        'rotation_period': {'seconds': days90},
        'next_rotation_time': {'seconds': int(time.time()) + days90},
    }

    try:
        crypto_key = kms_client.create_crypto_key(request={'parent': parent, 'crypto_key_id': crypto_key_id, 'crypto_key': crypto_key_init})
        print(f'Created Crypto Key {crypto_key.name}')
    except google_exc.AlreadyExists:
        print(f'Crypto Key {crypto_key_id} already exists. Using it...')

    key_name = kms_client.crypto_key_path(PROJECT_ID, cfg_data.get('gcp_region'), key_ring_id, crypto_key_id)

    def kms_encode(key, text, base64_encoded=False):
        encrypted = kms_client.encrypt(request={'name': key, 'plaintext': text.encode('utf-8')})

        if base64_encoded:
            return base64.b64encode(encrypted.ciphertext).decode('utf-8')
        return encrypted.ciphertext

    cfg_data['ad_password'] = kms_encode(key_name, cfg_data.get('ad_password'), True)
    cfg_data['reg_code'] = kms_encode(key_name, cfg_data.get('reg_code'), True)
    awm_deployment_key_encrypted = kms_encode(key_name, json.dumps(awm_deployment_key))

    print('Done encrypting secrets.')

    print('Creating Anyware Manager Deployment Service Account Key...')
    with open(AWM_DEPLOYMENT_SA_KEY_PATH, 'wb+') as keyfile:
        keyfile.write(awm_deployment_key_encrypted)

    print('  Key written to ' + AWM_DEPLOYMENT_SA_KEY_PATH)

    print('Deploying with Terraform...')

    #TODO: refactor this to work with more types of deployments
    settings = {
        'gcp_credentials_file':           cwd + GCP_SA_KEY_PATH,
        'gcp_region':                     cfg_data.get('gcp_region'),
        'gcp_zone':                       cfg_data.get('gcp_zone'),
        'kms_cryptokey_id':               key_name,
        'dc_admin_password':              cfg_data.get('ad_password'),
        'safe_mode_admin_password':       cfg_data.get('ad_password'),
        'ad_service_account_password':    cfg_data.get('ad_password'),
        'awc_admin_ssh_pub_key_file':     cwd + SSH_KEY_PATH + '.pub',
        'win_gfx_instance_count':         cfg_data.get('gwin'),
        'win_std_instance_count':         cfg_data.get('swin'),
        'centos_gfx_instance_count':      cfg_data.get('gcent'),
        'centos_std_instance_count':      cfg_data.get('scent'),
        'centos_admin_ssh_pub_key_file':  cwd + SSH_KEY_PATH + '.pub',
        'pcoip_registration_code':        cfg_data.get('reg_code'),
        'awm_deployment_sa_file':         cwd + AWM_DEPLOYMENT_SA_KEY_PATH,
        'prefix':                         prefix
    }

    # update tfvar
    tf_vars_create(TF_VARS_REF_PATH, TF_VARS_PATH, settings)

    tf_cmd = f'{TERRAFORM_BIN_PATH} init'
    subprocess.run(tf_cmd.split(' '), check=True)

    tf_cmd = f'{TERRAFORM_BIN_PATH} apply -auto-approve'
    subprocess.run(tf_cmd.split(' '), check=True)

    comp_proc = subprocess.run([TERRAFORM_BIN_PATH,'output','awc-public-ip'],
                               check=True,
                               stdout=subprocess.PIPE)
    awc_public_ip = comp_proc.stdout.decode().split('"')[1]

    print('Terraform deployment complete.\n')

    # To update the auth_token used by the session header for the API call
    # with the one from the deployment key in case the API Token expires
    my_awm.deployment_signin(awm_deployment_key)
    # Add existing workstations
    for t in WS_TYPES:
        for i in range(int(cfg_data.get(t))):
            hostname = f'{prefix}-{t}-{i}'
            print(f'Adding "{hostname}" to Anyware Manager...')
            my_awm.machine_add_existing(
                hostname,
                PROJECT_ID,
                cfg_data.get('gcp_zone'),
                deployment
            )

    print(f'Adding DC to Anyware Manager...')
    my_awm.machine_add_existing(
        f'{prefix}-vm-dc',
        PROJECT_ID,
        cfg_data.get('gcp_zone'),
        deployment
    )

    # Loop until Administrator user is found in Anyware Manager
    while True:
        entitle_user = my_awm.user_get(ENTITLE_USER, deployment)
        if entitle_user:
            break

        print(f'Waiting for user "{ENTITLE_USER}" to be synced. Retrying in 10 seconds...')
        time.sleep(10)

    # Add entitlements for each workstation
    machines_list = my_awm.machines_get(deployment)
    for machine in machines_list:
        print(f'Assigning workstation "{machine["machineName"]}" to user "{ENTITLE_USER}"...')
        my_awm.entitlement_add(entitle_user, machine)

    print('\nQuickstart deployment finished.\n')

    print('')
    next_steps = f"""
    Next steps:

    - Connect to a workstation:
    1. from a PCoIP client, connect to the HP Anyware Connector at {awc_public_ip}
    2. sign in with the "{ENTITLE_USER}" user credentials
    3. When connecting to a workstation immediately after this script completes,
        the workstation (especially graphics ones) may still be setting up. You may
        see "Remote Desktop is restarting..." in the client. Please wait a few
        minutes or reconnect if it times out.

    - Add additional workstations:
    1. Log in to https://cas.teradici.com
    2. Click on "Workstations" in the left panel, select "Create new remote
        workstation" from the "+" button
    3. Select connector "quickstart_awc_<timestamp>"
    4. Fill in the form according to your preferences. Note that the following
        values must be used for their respective fields:
        Region:                   "{cfg_data.get('gcp_region')}"
        Zone:                     "{cfg_data.get('gcp_zone')}"
        Network:                  "vpc-anyware"
        Subnetowrk:               "subnet-ws"
        Domain name:              "example.com"
        Domain service account:   "anyware_ad_admin"
        Service account password: <set by you at start of script>
    5. Click **Create**

    - Clean up:
    1. Using GCP console, delete all workstations created by Anyware Manager
        web interface and manually created workstations. Resources not created by
        the Terraform scripts must be manually removed before Terraform can
        properly destroy resources it created.
    2. In GCP cloudshell, change directory using the command "cd ~/cloudshell_open/cloud_deployment_scripts/{DEPLOYMENT_PATH}"
    3. Remove resources deployed by Terraform using the command "terraform destroy". Enter "yes" when prompted.
        "{'terraform' if TERRAFORM_BIN_PATH == shutil.which('terraform') else TERRAFORM_BIN_PATH} destroy"
    4. Go to https://console.cloud.google.com/logs/storage and delete the log bucket named "{prefix}-logging-bucket"
    5. Log in to https://cas.teradici.com and delete the deployment named
        "quickstart_deployment_<timestamp>"
    6. (Optional) We disabled _Default sink to avoid having duplicated logs. To re-enable the sink, run the GCP command "gcloud logging sinks update _Default --no-disabled"
    """

    print(next_steps)
    print('')
