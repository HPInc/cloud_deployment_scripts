#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation; © Copyright 2023 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import json
import requests

AWM_API_URL = "https://localhost/api/v1"
ADMIN_USER = "adminUser"

def awm_login(username, password):
    payload = {
        'username': username,
        'password': password,
    }
    resp = session.post(
        f"{AWM_API_URL}/auth/ad/login",
        json=payload,
    )
    resp.raise_for_status()

    token = resp.json()['data']['token']
    session.headers.update({"Authorization": token})


def deployment_create(name, reg_code):
    payload = {
        'deploymentName':   name,
        'registrationCode': reg_code,
    }
    resp = session.post(
        f"{AWM_API_URL}/deployments",
        json = payload,
    )
    resp.raise_for_status()

    return resp.json()['data']


def deployment_key_create(deployment, name):
    payload = {
        'deploymentId': deployment['deploymentId'],
        'keyName': name
    }
    resp = session.post(
        f"{AWM_API_URL}/auth/keys",
        json = payload,
    )
    resp.raise_for_status()

    return resp.json()['data']


def deployment_key_write(deployment_key, path):
    with open(path, 'w') as f:
        json.dump(deployment_key, f)


def get_gcp_sa_key(path):
    with open(path) as f:
        key = json.load(f)

    return key


def validate_gcp_sa(key):
    payload = {
        'provider': 'gcp',
        'credential': {
            'clientEmail': key['client_email'],
            'privateKey':  ''.join(key['private_key'].split('\n')[1:-2]),
            'projectId':   key['project_id'],
        },
    }
    resp = session.post(
        f"{AWM_API_URL}/auth/users/cloudServiceAccount/validate",
        json = payload,
    )

    try:
        resp.raise_for_status()
        return True

    except requests.exceptions.HTTPError as e:
        # Not failing because GCP service account is optional
        print("Error validating GCP Service Account key.")
        print(e)

        if resp.status_code == 400:
            print("ERROR: GCP Service Account key provided has insufficient permissions.")
            print(resp.json()['data'])

        return False


def deployment_add_gcp_account(key, deployment):
    credentials = {
        'clientEmail': key['client_email'],
        'privateKey':  ''.join(key['private_key'].split('\n')[1:-2]),
        'projectId':   key['project_id'],
    }
    payload = {
        'deploymentId': deployment['deploymentId'],
        'provider':     'gcp',
        'credential':   credentials,
    }
    resp = session.post(
        f"{AWM_API_URL}/auth/users/cloudServiceAccount",
        json = payload,
    )

    try:
        resp.raise_for_status()

    except requests.exceptions.HTTPError as e:
        # Not failing because GCP service account is optional
        print("Error adding GCP Service Account to deployment.")
        print(e)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="This script updates the password for the Anyware Manager Admin user.")

    parser.add_argument("--deployment_name", required=True, help="Anyware Manager deployment to create")
    parser.add_argument("--key_file", required=True, help="path to write Deployment Service Account key JSON file")
    parser.add_argument("--key_name", required=True, help="name of Anyware Manager Deployment Service Account key")
    parser.add_argument("--password", required=True, help="new Anyware Manager administrator password")
    parser.add_argument("--reg_code", required=True, help="PCoIP registration code")
    parser.add_argument("--gcp_key", help="GCP Service Account credential key path")

    args = parser.parse_args()

    # Set up session to be used for all subsequent calls to Anyware Manager
    session = requests.Session()
    session.verify = False
    retry_strategy = requests.adapters.Retry(
        total=10,
        backoff_factor=1,
        status_forcelist=[500,502,503,504],
        allowed_methods=["POST"] # "method_whitelist" deprecated
    )
    session.mount(
        "https://", requests.adapters.HTTPAdapter(max_retries=retry_strategy)
    )

    # The credential for Anyware Manager login are stated in default configuration
    # https://www.teradici.com/web-help/anyware_manager/23.04/cam_standalone_installation/default_config/#5-access-the-admin-console
    print("Creating Anyware Manager deployment...")
    awm_login(ADMIN_USER, args.password)
    deployment = deployment_create(args.deployment_name, args.reg_code)
    awm_deployment_key = deployment_key_create(deployment, args.key_name)
    deployment_key_write(awm_deployment_key, args.key_file)

    if args.gcp_key:
        gcp_sa_key = get_gcp_sa_key(args.gcp_key)

        print("Validating GCP credentials with Anyware Manager...")
        valid = validate_gcp_sa(gcp_sa_key)

        if valid:
            print("Adding GCP credentials to Anyware Manager deployment...")
            deployment_add_gcp_account(gcp_sa_key, deployment)
        else:
            print("WARNING: GCP credentials validation failed. Skip adding GCP credentials to Anyware Manager deployment.")
