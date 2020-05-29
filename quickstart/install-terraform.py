# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import os
import pathlib
import shutil
import sys
import urllib.request
import zipfile


TEMP_DIR           = '/tmp'
TERRAFORM_VERSION  = '0.12.3'
HOME               = os.path.expanduser('~')
TERRAFORM_BIN_DIR  = f'{HOME}/bin'
TERRAFORM_BIN_PATH = TERRAFORM_BIN_DIR + '/terraform'


def terraform_install(version=TERRAFORM_VERSION):

    zip_filename = 'terraform_{}_linux_amd64.zip'.format(version)
    download_url = 'https://releases.hashicorp.com/terraform/{}/{}'.format(version, zip_filename)
    local_zip_file = TEMP_DIR + '/' + zip_filename

    print('Downloading from {} to {}...'.format(download_url, local_zip_file))
    urllib.request.urlretrieve(download_url, local_zip_file)

    print('Extracting to {}...'.format(TERRAFORM_BIN_DIR))
    pathlib.Path(TERRAFORM_BIN_DIR).mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(local_zip_file) as tf_zip_file:
        tf_zip_file.extractall(TERRAFORM_BIN_DIR)

    os.chmod(TERRAFORM_BIN_PATH, 0o775)

    print('Deleting {}...'.format(local_zip_file))
    os.remove(local_zip_file)

    print('Terraform version {} installed.'.format(version))


if __name__ == '__main__':
    # Set up argparse
    parser_description = ('Installs Terraform in the specified directory.')

    parser = argparse.ArgumentParser(description=parser_description)
    parser.add_argument('dir', help='specify the directory to install Terraform')
    args = parser.parse_args()

    TERRAFORM_BIN_DIR = args.dir

    # Don't attempt to install unless needed
    path = shutil.which('terraform')
    if path:
        print('Terraform already installed in ' + path)
        sys.exit()

    terraform_install()
