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
TERRAFORM_VERSION  = '0.14.0'


def terraform_install(terraform_bin_dir, version):
    zip_filename = f'terraform_{version}_linux_amd64.zip'
    download_url = f'https://releases.hashicorp.com/terraform/{version}/{zip_filename}'
    local_zip_file = TEMP_DIR + '/' + zip_filename

    print(f'Downloading from {download_url} to {local_zip_file}...')
    urllib.request.urlretrieve(download_url, local_zip_file)

    print(f'Extracting to {terraform_bin_dir}...')
    pathlib.Path(terraform_bin_dir).mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(local_zip_file) as tf_zip_file:
        tf_zip_file.extractall(terraform_bin_dir)

    os.chmod(terraform_bin_dir + '/terraform', 0o775)

    print(f'Deleting {local_zip_file}...')
    os.remove(local_zip_file)

    print(f'Terraform version {version} installed.')


if __name__ == '__main__':
    # Set up argparse
    parser_description = ('Installs Terraform in the specified directory.')

    parser = argparse.ArgumentParser(description=parser_description)
    parser.add_argument('dir', help='specify the directory to install Terraform')
    parser.add_argument('ver', nargs='?', default=TERRAFORM_VERSION, help='specify the version of Terraform to install')
    args = parser.parse_args()

    terraform_install(args.dir, args.ver)
