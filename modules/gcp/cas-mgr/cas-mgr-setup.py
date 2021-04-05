#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import json 
import requests

CAS_MGR_API_URL = "https://localhost/api/v1"
TEMP_CRED_PATH = "/opt/teradici/casm/temp-creds.txt"


def get_temp_creds(path=TEMP_CRED_PATH):
    data = {}

    with open(path, 'r') as f:
        for line in f:
            key, value = map(str.strip, line.split(":"))
            data[key] = value

    return data['username'], data['password']


def cas_mgr_login(username, password):
    payload = {
        'username': username, 
        'password': password,
    }
    resp = session.post(
        f"{CAS_MGR_API_URL}/auth/ad/login",
        json=payload, 
    )
    resp.raise_for_status()

    token = resp.json()['data']['token']
    session.headers.update({"Authorization": token})


def password_change(new_password):
    payload = {'password': new_password}
    resp = session.post(
        f"{CAS_MGR_API_URL}/auth/ad/adminPassword",
        json=payload,
    )
    resp.raise_for_status()


def deployment_create(name, reg_code):
    payload = {
        'deploymentName':   name,
        'registrationCode': reg_code,
    }
    resp = session.post(
        f"{CAS_MGR_API_URL}/deployments",
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
        f"{CAS_MGR_API_URL}/auth/keys",
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
        f"{CAS_MGR_API_URL}/auth/users/cloudServiceAccount/validate",
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
        f"{CAS_MGR_API_URL}/auth/users/cloudServiceAccount",
        json = payload,
    )

    try:
        resp.raise_for_status()

    except requests.exceptions.HTTPError as e:
        # Not failing because GCP service account is optional
        print("Error adding GCP Service Account to deployment.")
        print(e)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="This script updates the password for the CAS Manager Admin user.")

    parser.add_argument("--deployment_name", required=True, help="CAS Manager deployment to create")
    parser.add_argument("--key_file", required=True, help="path to write Deployment Service Account key JSON file")
    parser.add_argument("--key_name", required=True, help="name of CAS Manager Deployment Service Account key")
    parser.add_argument("--password", required=True, help="new CAS Manager administrator password")
    parser.add_argument("--reg_code", required=True, help="PCoIP registration code")
    parser.add_argument("--gcp_key", help="GCP Service Account credential key path")

    args = parser.parse_args()

    # Set up session to be used for all subsequent calls to CAS Manager
    session = requests.Session()
    session.verify = False

    print("Setting CAS Manager Administrator password...")
    user, password = get_temp_creds()
    cas_mgr_login(user, password)
    password_change(args.password)

    print("Creating CAS Manager deployment...")
    cas_mgr_login(user, args.password)
    deployment = deployment_create(args.deployment_name, args.reg_code)
    cas_mgr_deployment_key = deployment_key_create(deployment, args.key_name)
    deployment_key_write(cas_mgr_deployment_key, args.key_file)

    if args.gcp_key:
        gcp_sa_key = get_gcp_sa_key(args.gcp_key)

        print("Validating GCP credentials with CAS Manager...")
        valid = validate_gcp_sa(gcp_sa_key)

        if valid:
            print("Adding GCP credentials to CAS Manager deployment...")
            deployment_add_gcp_account(gcp_sa_key, deployment)
        else:
            print("WARNING: GCP credentials validation failed. Skip adding GCP credentials to CAS Manager deployment.")
