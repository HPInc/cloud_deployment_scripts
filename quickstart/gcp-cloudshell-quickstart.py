#!/usr/bin/env python3

# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import datetime
import getpass
import importlib
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time

import cam

REQUIRED_PACKAGES = {
    'google-api-python-client': None, 
    'grpc-google-iam-v1': None, 
    'google-cloud-kms': "2.0.0"
}

# Service Account ID of the service account to create
SA_ID       = 'cloud-access-manager'
SA_ROLES    = [
    'roles/editor',
    'roles/cloudkms.cryptoKeyEncrypterDecrypter'
]

PROJECT_ID = os.environ['GOOGLE_CLOUD_PROJECT']
GCP_REGION = 'us-west2'
REQUIRED_APIS = [
    'deploymentmanager.googleapis.com',
    'cloudkms.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'compute.googleapis.com',
    'dns.googleapis.com',
    'iam.googleapis.com',
]

iso_time = datetime.datetime.utcnow().isoformat(timespec='seconds').replace(':','').replace('-','') + 'Z'
DEPLOYMENT_NAME = 'quickstart_deployment_' + iso_time
CONNECTOR_NAME  = 'quickstart_cac_' + iso_time

# User entitled to workstations
ENTITLE_USER = 'Administrator'

HOME               = os.path.expanduser('~')
TERRAFORM_BIN_DIR  = f'{HOME}/bin'
TERRAFORM_BIN_PATH = TERRAFORM_BIN_DIR + '/terraform'
TERRAFORM_VER_PATH = '../deployments/gcp/single-connector/versions.tf'
CFG_FILE_PATH      = 'gcp-cloudshell-quickstart.cfg'
DEPLOYMENT_PATH    = 'deployments/gcp/single-connector'

# All of the following paths are relative to the deployment directory, DEPLOYMENT_PATH
TF_VARS_REF_PATH = 'terraform.tfvars.sample'
TF_VARS_PATH     = 'terraform.tfvars'
SECRETS_DIR      = 'secrets'
GCP_SA_KEY_PATH  = SECRETS_DIR + '/gcp_service_account_key.json'
SSH_KEY_PATH     = SECRETS_DIR + '/cam_admin_id_rsa'
CAM_DEPLOYMENT_SA_KEY_PATH = SECRETS_DIR + '/cam_deployment_sa_key.json.encrypted'

# Types of workstations
WS_TYPES = ['scent', 'gcent', 'swin', 'gwin']

next_steps = """
Next steps:

- Connect to a workstation:
  1. from a PCoIP client, connect to the Cloud Access Connector at {cac_public_ip}
  2. sign in with the "{entitle_user}" user credentials
  3. When connecting to a workstation immediately after this script completes,
     the workstation (especially graphics ones) may still be setting up. You may
     see "Remote Desktop is restarting..." in the client. Please wait a few
     minutes or reconnect if it times out.

- Add additional workstations:
  1. Log in to https://cam.teradici.com
  2. Click on "Workstations" in the left panel, select "Create new remote
     workstation" from the "+" button
  3. Select connector "quickstart_cac_<timestamp>"
  4. Fill in the form according to your preferences. Note that the following
     values must be used for their respective fields:
       Region:                   "us-west2"
       Zone:                     "us-west2-b"
       Network:                  "vpc-cas"
       Subnetowrk:               "subnet-ws"
       Domain name:              "example.com"
       Domain service account:   "cam_admin"
       Service account password: <set by you at start of script>
  5. Click **Create**

- Clean up:
  1. Using GCP console, delete all workstations created by Cloud Access Manager
     web interface and manually created workstations. Resources not created by
     the Terraform scripts must be manually removed before Terraform can
     properly destroy resources it created.
  2. In GCP cloudshell, change directory using the command "cd ~/cloudshell_open/cloud_deployment_scripts/{deployment_path}"
  3. Remove resources deployed by Terraform using the command "terraform destroy". Enter "yes" when prompted.
     "{terraform_path} destroy"
  4. Log in to https://cam.teradici.com and delete the deployment named
     "quickstart_deployment_<timestamp>"
"""

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

    if path:
        cmd = 'terraform -v'
        # Run the command 'terraform -v' and use the first line as the Terraform version
        terraform_version = subprocess.run(cmd.split(' '),  stdout=subprocess.PIPE).stdout.decode('utf-8').splitlines()[0]
        print(f'Found {terraform_version} in {path}.')

        # Use regex to parse the version number from string (i.e. 0.12.18)
        current_version = re.search(r'Terraform\s*v([\d.]+)', terraform_version).group(1)

        # Reference versions.tf file for the required version
        with open(TERRAFORM_VER_PATH,"r") as f:
            data = f.read()
        
        required_version = re.search(r'\">=\s([\d.]+)\"', data).group(1)

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

    install_cmd = f'{sys.executable} install-terraform.py {TERRAFORM_BIN_DIR}'
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
    print(textwrap.dedent(txt))
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
        print('  Service account {} already exists.'.format(email))
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
        overwrite = input("Found an existing .tfvar file, overwrite (y/n)? ").strip().lower()
        if overwrite not in ('y', 'yes'):
            print('{} already exists. Exiting...'.format(tfvar_file_path))
            sys.exit(1)

    with open(ref_file_path, 'r') as ref_file, open(tfvar_file_path, 'w') as out_file:
        for line in ref_file:
            # Append the crypto key path to kms_cryptokey_id line since it is commented out in ref_file
            if '# kms_cryptokey_id' in line:
                out_file.write('{} = \"{}\"'.format('kms_cryptokey_id', settings['kms_cryptokey_id']))
                continue

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


if __name__ == '__main__':
    ensure_requirements()

    cfg_data = quickstart_config_read(CFG_FILE_PATH)

    password = ad_password_get()

    print('Preparing local requirements...')
    os.chdir('../')
    os.chdir(DEPLOYMENT_PATH)
    # Paths passed into terraform.tfvars should be absolute paths
    cwd = os.getcwd() + '/'

    try:
        print('Creating directory {} to store secrets...'.format(SECRETS_DIR))
        os.mkdir(SECRETS_DIR, 0o700)
    except FileExistsError:
        print('Directory {} already exists.'.format(SECRETS_DIR))

    ssh_key_create(SSH_KEY_PATH)

    print('Local requirements setup complete.\n')

    print('Setting GCP project...')
    sa_email = '{}@{}.iam.gserviceaccount.com'.format(SA_ID, PROJECT_ID)
    iam_service = googleapiclient.discovery.build('iam', 'v1')
    crm_service = googleapiclient.discovery.build('cloudresourcemanager', 'v1')

    apis_enable(REQUIRED_APIS)
    sa = service_account_create(sa_email)
    iam_policy_update(sa, SA_ROLES)
    sa_key = service_account_create_key(sa, GCP_SA_KEY_PATH)

    print('GCP project setup complete.\n')

    print('Setting Cloud Access Manager...')
    mycam = cam.CloudAccessManager(cfg_data.get('api_token'))

    print('Creating deployment {}...'.format(DEPLOYMENT_NAME))
    deployment = mycam.deployment_create(DEPLOYMENT_NAME, cfg_data.get('reg_code'))
    mycam.deployment_add_gcp_account(sa_key, deployment)

    print('Creating CAM API key...')
    cam_deployment_key = mycam.deployment_key_create(deployment)

    print('Cloud Access Manager setup complete.\n')

    print('Encrypting secrets...')
    days90 = 7776000

    kms_client = kms.KeyManagementServiceClient()

    parent = f'projects/{PROJECT_ID}/locations/{GCP_REGION}'
    key_ring_id = 'cloud_deployment_scripts'
    key_ring_init = {}

    try:
        key_ring = kms_client.create_key_ring(request={'parent': parent, 'key_ring_id': key_ring_id, 'key_ring': key_ring_init})
        print('Created Key Ring {}'.format(key_ring.name))
    except google_exc.AlreadyExists:
        print('Key Ring {} already exists. Using it...'.format(key_ring_id))

    parent = kms_client.key_ring_path(PROJECT_ID, GCP_REGION, key_ring_id)
    crypto_key_id = 'quickstart_key'
    crypto_key_init = {
        'purpose': kms.CryptoKey.CryptoKeyPurpose.ENCRYPT_DECRYPT,
        'rotation_period': {'seconds': days90},
        'next_rotation_time': {'seconds': int(time.time()) + days90},
    }

    try:
        crypto_key = kms_client.create_crypto_key(request={'parent': parent, 'crypto_key_id': crypto_key_id, 'crypto_key': crypto_key_init})
        print('Created Crypto Key {}'.format(crypto_key.name))
    except google_exc.AlreadyExists:
        print('Crypto Key {} already exists. Using it...'.format(crypto_key_id))

    key_name = kms_client.crypto_key_path(PROJECT_ID, GCP_REGION, key_ring_id, crypto_key_id)

    def kms_encode(key, text):
        encrypted = kms_client.encrypt(request={'name': key, 'plaintext': text.encode('utf-8')})

        return base64.b64encode(encrypted.ciphertext).decode('utf-8')

    password = kms_encode(key_name, password)
    cfg_data['reg_code'] = kms_encode(key_name, cfg_data.get('reg_code'))
    cam_deployment_key = kms_encode(key_name, json.dumps(cam_deployment_key))

    print('Done encrypting secrets.')

    print('Creating CAM Deployment Service Account Key...')
    with open(CAM_DEPLOYMENT_SA_KEY_PATH, 'w+') as keyfile:
        keyfile.write(cam_deployment_key)

    print('  Key written to ' + CAM_DEPLOYMENT_SA_KEY_PATH)

    print('Deploying with Terraform...')

    #TODO: refactor this to work with more types of deployments
    settings = {
        'gcp_credentials_file':           cwd + GCP_SA_KEY_PATH,
        'gcp_project_id':                 PROJECT_ID,
        'gcp_service_account':            sa_email,
        'kms_cryptokey_id':               key_name,
        'dc_admin_password':              password,
        'safe_mode_admin_password':       password,
        'ad_service_account_password':    password,
        'cac_admin_ssh_pub_key_file':     cwd + SSH_KEY_PATH + '.pub',
        'win_gfx_instance_count':         cfg_data.get('gwin'),
        'win_std_instance_count':         cfg_data.get('swin'),
        'centos_gfx_instance_count':      cfg_data.get('gcent'),
        'centos_std_instance_count':      cfg_data.get('scent'),
        'centos_admin_ssh_pub_key_file':  cwd + SSH_KEY_PATH + '.pub',
        'pcoip_registration_code':        cfg_data.get('reg_code'),
        'cam_deployment_sa_file':         cwd + CAM_DEPLOYMENT_SA_KEY_PATH
    }

    # update tfvar
    tf_vars_create(TF_VARS_REF_PATH, TF_VARS_PATH, settings)

    tf_cmd = f'{TERRAFORM_BIN_PATH} init'
    subprocess.run(tf_cmd.split(' '), check=True)

    tf_cmd = f'{TERRAFORM_BIN_PATH} apply -auto-approve'
    subprocess.run(tf_cmd.split(' '), check=True)

    comp_proc = subprocess.run([TERRAFORM_BIN_PATH,'output','cac-public-ip'],
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

    print('')
    print(next_steps.format(cac_public_ip=cac_public_ip,
                            entitle_user=ENTITLE_USER,
                            deployment_path=DEPLOYMENT_PATH,
                            terraform_path=('terraform'
                            if TERRAFORM_BIN_PATH == shutil.which('terraform') 
                            else TERRAFORM_BIN_PATH)))
    print('')
