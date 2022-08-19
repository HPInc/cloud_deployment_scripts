#!/usr/bin/env python3

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import datetime
import getpass
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

REQUIRED_PACKAGES = {
    'boto3': None, 
    'retry': None, 
    'requests': None,
}

iso_time = datetime.datetime.utcnow().isoformat(timespec='seconds').replace(':','').replace('-','') + 'Z'
DEPLOYMENT_NAME = 'quickstart_deployment_' + iso_time

# User entitled to workstations
ENTITLE_USER = 'Administrator'

HOME               = os.path.expanduser('~')
TERRAFORM_BIN_DIR  = os.path.join(HOME, 'bin')
TERRAFORM_BIN_PATH = os.path.join(TERRAFORM_BIN_DIR, 'terraform')

os.chdir('../../')
REPOSITORY_PATH    = os.getcwd()
DEPLOYMENT_PATH    = os.path.join(REPOSITORY_PATH, 'deployments/aws/single-connector/')
QUICKSTART_PATH    = os.path.join(REPOSITORY_PATH, 'quickstart/aws/')
KMS_ENCRYPTOR_PATH = os.path.join(REPOSITORY_PATH, 'tools/')
INSTALL_TERRAFORM  = os.path.join(REPOSITORY_PATH, 'tools/install-terraform.py')
TERRAFORM_VER_PATH = os.path.join(DEPLOYMENT_PATH, 'versions.tf')
SECRETS_DIR        = os.path.join(DEPLOYMENT_PATH, 'secrets/')

# Setting paths for secrets
SSH_KEY_PATH                   = os.path.join(SECRETS_DIR, 'cas_mgr_admin_id_rsa')
CAS_MGR_DEPLOYMENT_SA_KEY_PATH = os.path.join(SECRETS_DIR, 'cas_mgr_deployment_sa_key.json')
AWS_SA_KEY_PATH                = os.path.join(SECRETS_DIR, 'aws_service_account_credentials')
ARN_FILE_PATH                  = os.path.join(SECRETS_DIR, 'arn.txt')

# Setting paths for terraform.tfvars
TF_VARS_REF_PATH = os.path.join(DEPLOYMENT_PATH, 'terraform.tfvars.sample')
TF_VARS_PATH     = os.path.join(DEPLOYMENT_PATH, 'terraform.tfvars')

CFG_FILE_PATH        = os.path.join(QUICKSTART_PATH, 'aws-quickstart.cfg')
ROLE_POLICY_DOCUMENT = os.path.join(QUICKSTART_PATH, 'cas-mgr-power-manage-role-policy.json')
AWS_USER_POLICY_ARN  = "arn:aws:iam::aws:policy/AdministratorAccess"

# Types of workstations
WS_TYPES = ['scent', 'gcent', 'swin', 'gwin']

def ensure_requirements():
    ensure_required_packages()
    import_modules()
    ensure_terraform()
    ensure_aws_cli()


def ensure_required_packages():
    """A function that ensures the correct version of Python packages are installed. 

    The function first checks if the required packages are installed. If a package is 
    installed, the required version number will then be checked. It will next prompt 
    the user to update or install the required packages.
    """

    update_cmd = 'pip3 install --upgrade pip --user'
    subprocess.run(update_cmd.split(' '), check=True)

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
            current_version_tuple = tuple( map(int, current_version.split('.')) )
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
    """A function that dynamically imports required modules.
    """

    # Global calls for import statements are required to avoid module not found error
    import_required_packages = '''\
        import casmgr
        import aws_iam_wrapper as aws
        import interactive
    '''

    # Recommended to clear cache after installing python packages for dynamic imports
    importlib.invalidate_caches()

    exec(textwrap.dedent(import_required_packages), globals())
    print('Successfully imported required modules.')


def ensure_terraform():
    """A function that ensures the required Terraform version is installed. 

    The function first checks if the required Terraform version is installed in 
    the user's system. If Terraform is not installed, it will prompt the user to 
    install Terraform in the user's home directory. 
    """

    path = shutil.which('terraform')

    # Reference versions.tf file for the required version
    with open(TERRAFORM_VER_PATH,"r") as f:
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
        current_version_tuple = tuple( map(int, current_version.split('.')) )
        required_version_tuple = tuple( map(int, required_version.split('.')) )

        if current_version_tuple >= required_version_tuple:
            global TERRAFORM_BIN_PATH
            TERRAFORM_BIN_PATH = path
            return

    install_permission = input(
        f'This system is missing Terraform version >= {required_version}.\n'
        f'Proceed to download and install Terraform in {TERRAFORM_BIN_DIR} (y/n)? ').strip().lower()

    if install_permission not in ('y', 'yes'):
        print('Terraform is required for deployment. Exiting...')
        sys.exit(1)

    install_cmd = f'{sys.executable} {INSTALL_TERRAFORM} {TERRAFORM_BIN_DIR}'
    subprocess.run(install_cmd.split(' '), check=True)


def ensure_aws_cli():
    path = shutil.which('aws')
    if path:
        cmd = 'aws --version'
        # Command returns a string 'aws-cli/1.16.300 Python/2.7.18 Linux/4.14.186-146.268.amzn2.x86_64 botocore/1.13.36'
        # Stderr redirection is required as that's where the output of the command is printed out to
        output = subprocess.run(cmd.split(' '), stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
        aws_cli_version = output.stdout.decode('utf-8').split(' ', 1)[0].split('/', 1)[1]
        print(f'Found AWS CLI {aws_cli_version} in {path}.')
        return

    # TODO Add install-aws-cli.py script similar to install-terraform.py if AWS CLI is not installed.

    print('AWS CLI not found. Please install and try again. Exiting...\n')
    sys.exit(1)


def ad_password_get():
    txt = r'''
    Please enter a password for the Active Directory Administrator.

    Note Windows passwords must be at least 7 characters long and meet complexity
    requirements:
    1. Must not contain user's account name or display name
    2. Must have 3 of the following categories:
       - a-z
       - A-Z
       - 0-9
       - special characters: ~!@#$%^&*_-+=`|\(){}[]:;"'<>,.?/
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

            if '# aws_region' in line:
                out_file.write(f'{"aws_region"} = \"{settings["aws_region"]}\"')
            
            elif '# prefix' in line:
                out_file.write(f'{"prefix"} = \"{PREFIX}\"')
            
            # Comments and blank lines are unchanged
            elif line[0] in ('#', '\n'):
                out_file.write(line)
            
            else:
                key = line.split('=')[0].strip()
                try:
                    out_file.write(f'{key} = "{settings[key]}"\n')
                except KeyError:
                    # Remove file and error out
                    os.remove(tfvar_file_path)
                    print(f'Required value for {key} missing. tfvars file {tfvar_file_path} not created.')
                    sys.exit(1)


if __name__ == '__main__':
    ensure_requirements()

    print('\nValidating AWS credentials...')
    if not aws.validate_credentials():
        exit(1)
    print("")

    cfg_data = interactive.configurations_get(WS_TYPES, ENTITLE_USER, QUICKSTART_PATH)

    print('\nPreparing local requirements...')

    try:
        print(f'Creating directory {SECRETS_DIR} to store secrets...')
        os.mkdir(SECRETS_DIR, 0o700)
    except FileExistsError:
        print(f'Directory {SECRETS_DIR} already exists.')

    ssh_key_create(SSH_KEY_PATH)

    print('Local requirements setup complete.\n')

    print('Setting CAS Manager...')
    mycasmgr = casmgr.CASManager(cfg_data.get('api_token'))

    print(f'Creating deployment {DEPLOYMENT_NAME}...')
    deployment = mycasmgr.deployment_create(DEPLOYMENT_NAME, cfg_data.get('reg_code'))
    role_info = mycasmgr.generate_aws_role_info(deployment)

    print('Creating CAS Manager API key...')
    cas_mgr_deployment_key = mycasmgr.deployment_key_create(deployment)
    with open(CAS_MGR_DEPLOYMENT_SA_KEY_PATH, 'w+') as keyfile:
        keyfile.write(json.dumps(cas_mgr_deployment_key))
    print('  Key written to ' + CAS_MGR_DEPLOYMENT_SA_KEY_PATH)
    print('CAS Manager setup complete.\n')

    print('Creating AWS user for Terraform deployment...')
    AWS_REGION = cfg_data.get('aws_region')
    PREFIX = cfg_data.get('prefix', '')
    AWS_USERNAME = PREFIX + '-cas-manager'
    AWS_ROLE_NAME = f'{AWS_USERNAME}_role'
    ROLE_POLICY_NAME = f'{AWS_ROLE_NAME}_policy'

    aws.create_user(AWS_USERNAME)
    aws.attach_user_policy(AWS_USERNAME, AWS_USER_POLICY_ARN)
    
    print('Creating AWS role for CAS Manager deployment...')
    role = aws.create_role(AWS_ROLE_NAME, role_info['camAccountId'], role_info['externalId'])
    role_policy_description = "Permissions to allow managing instances using CAS Manager"
    role_policy = aws.create_policy(ROLE_POLICY_NAME, role_policy_description, ROLE_POLICY_DOCUMENT)
    aws.attach_role_policy(AWS_ROLE_NAME, ROLE_POLICY_NAME)
    
    print('Creating AWS service account key for Terraform deployment...')
    # This is done last because the number of keys a user can have is limited
    # so if issues occur when creating other IAM resources, the key won't easily run out
    sa_key_id = aws.service_account_create_key(AWS_USERNAME, AWS_SA_KEY_PATH)

    print('Registering AWS role to CAS Manager deployment...')
    mycasmgr.deployment_add_aws_account(deployment, role.get('Arn'))

    # Newly created IAM access key needs to wait to avoid security token error
    time.sleep(5)
    print('AWS setup complete.\n')

    print('Deploying with Terraform...')
    settings = {
        'aws_credentials_file':           AWS_SA_KEY_PATH,
        'aws_region':                     AWS_REGION,
        'dc_admin_password':              cfg_data.get('ad_password'),
        'safe_mode_admin_password':       cfg_data.get('ad_password'),
        'ad_service_account_password':    cfg_data.get('ad_password'),
        'admin_ssh_pub_key_file':         SSH_KEY_PATH + '.pub',
        'win_gfx_instance_count':         cfg_data.get('gwin'),
        'win_std_instance_count':         cfg_data.get('swin'),
        'centos_gfx_instance_count':      cfg_data.get('gcent'),
        'centos_std_instance_count':      cfg_data.get('scent'),
        'pcoip_registration_code':        cfg_data.get('reg_code'),
        'cas_mgr_deployment_sa_file':     CAS_MGR_DEPLOYMENT_SA_KEY_PATH,
        'prefix':                         PREFIX,
    }

    # update tfvar
    tf_vars_create(TF_VARS_REF_PATH, TF_VARS_PATH, settings)
    # Newly created tfvars files might need a few seconds to write
    time.sleep(5)

    print('Encrypting secrets...')
    os.chdir(KMS_ENCRYPTOR_PATH)
    command = f'{sys.executable} kms_secrets_encryption.py {TF_VARS_PATH}'
    subprocess.run(command.split(' '), check=True)
    print('Done encrypting secets...')

    os.chdir(DEPLOYMENT_PATH)
    tf_cmd = f'{TERRAFORM_BIN_PATH} init'
    subprocess.run(tf_cmd.split(' '), check=True)

    tf_cmd = f'{TERRAFORM_BIN_PATH} apply -auto-approve'
    subprocess.run(tf_cmd.split(' '), check=True)

    comp_proc = subprocess.run([TERRAFORM_BIN_PATH,'output','awc-public-ip'],
                               check=True,
                               stdout=subprocess.PIPE)
    awc_public_ip = comp_proc.stdout.decode().split('"')[1]

    # Newly created AWS instances might need a few seconds to sync to CAS Manager
    time.sleep(10)
    print('Terraform deployment complete.\n')

    # Add existing workstations
    mycasmgr.deployment_signin(cas_mgr_deployment_key)
    for t in WS_TYPES:
        for i in range(int(cfg_data.get(t))):
            hostname = f'{PREFIX}-{t}-{i}'
            print(f'Adding "{hostname}" to CAS Manager...')
            mycasmgr.machine_add_existing(
                hostname,
                deployment,
                AWS_REGION,
            )

    # Loop until Administrator user is found in CAS Manager
    while True:
        entitle_user = mycasmgr.user_get(ENTITLE_USER, deployment)
        if entitle_user:
            break

        print(f'Waiting for user "{ENTITLE_USER}" to be synced. Retrying in 10 seconds...')
        time.sleep(10)

    # Add entitlements for each workstation
    machines_list = mycasmgr.machines_get(deployment)
    for machine in machines_list:
        print(f'Assigning workstation "{machine["machineName"]}" to user "{ENTITLE_USER}"...')
        mycasmgr.entitlement_add(entitle_user, machine)

    print('\nQuickstart deployment finished.\n')

    print('')
    next_steps = f"""
    Next steps:

    - Connecting to Workstations:
    1.  From a PCoIP client, connect to the Anyware Connector at {awc_public_ip}. 
        To install a PCoIP client, please see: https://docs.teradici.com/find/product/software-and-mobile-clients
    2.  Sign in with the "{ENTITLE_USER}" user credentials
    3.  When connecting to a workstation immediately after this script completes,
        the workstation (especially graphics ones) may still be setting up. You may
        see "Remote Desktop is restarting..." in the client. Please wait a few
        minutes or reconnect if it times out.

    - Deleting the Deployment:
    1.  Make sure you are at the right directory using the command "cd {DEPLOYMENT_PATH}"
    2.  Remove resources deployed by Terraform using the following command. Enter "yes" when prompted.
        "{'terraform' if TERRAFORM_BIN_PATH == shutil.which('terraform') else TERRAFORM_BIN_PATH} destroy"
    3.  Log in to https://cas.teradici.com and delete the deployment named
        "{DEPLOYMENT_NAME}"

    - Deleting the AWS IAM Resources:
    1.  The script created an IAM policy, role, access key, and user to allow Terraform to create and CAS Manager to 
        manage AWS resources. Before removing these IAM resources, you must first make sure to complete all previous 
        steps to delete the deployment.
    2.  Then, run the following commands:
        aws iam detach-role-policy --role-name {AWS_ROLE_NAME} --policy-arn {aws.get_policy_arn(ROLE_POLICY_NAME)}
        aws iam delete-policy --policy-arn {aws.get_policy_arn(ROLE_POLICY_NAME)}
        aws iam delete-role --role-name {AWS_ROLE_NAME}
        aws iam delete-access-key --user-name {AWS_USERNAME} --access-key-id {sa_key_id}
        aws iam detach-user-policy --user-name {AWS_USERNAME} --policy-arn {AWS_USER_POLICY_ARN}
        aws iam delete-user --user-name {AWS_USERNAME}
    """

    print(next_steps)
    print('')
