#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import json 
import requests
import configparser
import boto3
from botocore.exceptions import ClientError

CAM_API_URL = "https://localhost/api/v1"
TEMP_CRED_PATH = "/opt/teradici/casm/temp-creds.txt"


def get_temp_creds(path=TEMP_CRED_PATH):
    data = {}

    with open(path, 'r') as f:
        for line in f:
            key, value = map(str.strip, line.split(":"))
            data[key] = value

    return data['username'], data['password']


def cam_login(username, password):
    payload = {
        'username': username, 
        'password': password,
    }
    resp = session.post(
        f"{CAM_API_URL}/auth/ad/login",
        json=payload, 
    )
    resp.raise_for_status()

    token = resp.json()['data']['token']
    session.headers.update({"Authorization": token})


def password_change(new_password):
    payload = {'password': new_password}
    resp = session.post(
        f"{CAM_API_URL}/auth/ad/adminPassword",
        json=payload,
    )
    resp.raise_for_status()


def deployment_create(name, reg_code):
    payload = {
        'deploymentName':   name,
        'registrationCode': reg_code,
    }
    resp = session.post(
        f"{CAM_API_URL}/deployments",
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
        f"{CAM_API_URL}/auth/keys",
        json = payload,
    )
    resp.raise_for_status()

    return resp.json()['data']


def deployment_key_write(deployment_key, path):
    with open(path, 'w') as f:
        json.dump(deployment_key, f)


def parse_aws_sa_key(path):
    config = configparser.ConfigParser()
    config.read(path)
    return config['default']


def get_username(credentials):
    iam = boto3.resource('iam')
    users = list(iam.users.all())
    try:
        for user in users:
            if user.user_id == credentials['aws_access_key_id']:
                return user.user_name
        print("Warning: no username found with the specified credentials.")
    except ClientError as e:
        print("Warning: error retrieving AWS username.")
        print(e)
    return None


def validate_aws_credentials(username, credentials):
    print("Validating AWS cloud service account...")
    payload = {
        'provider': 'aws',
        'credential': {
            'userName': username,
            'accessKeyId': credentials['aws_access_key_id'],
            'secretAccessKey': credentials['aws_secret_access_key'],
        }
    }
    resp = session.post(
        f"{CAM_API_URL}/auth/users/cloudServiceAccount/validate",
        json = payload,
    )
    try:
        resp.raise_for_status()
        return True
    except requests.exceptions.HTTPError as e:
        print("Warning: error validating AWS Service Account key.")
        print(e)


def deployment_register_service_account(userame, credentials, deployment):
    print("Adding AWS cloud service account to deployment...")
    payload = {
        'provider': 'aws',
        'credential': {
            'userName': username,
            'accessKeyId': credentials['aws_access_key_id'],
            'secretAccessKey': credentials['aws_secret_access_key'],
        }
    }
    resp = session.post(
        f"{CAM_API_URL}/deployments/{deployment['deploymentId']}/cloudServiceAccounts",
        json = payload,
    )
    try:
        resp.raise_for_status()
        print("Successfully added AWS cloud service account to deployment.")
    except requests.exceptions.HTTPError as e:
        # Not failing because AWS service account is optional
        print("Warning: error adding AWS cloud service account to deployment.")
        print(e)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="This script updates the password for the CAM Admin user.")

    parser.add_argument("--deployment_name", required=True, help="CAM deployment to create")
    parser.add_argument("--key_file", required=True, help="path to write Deployment Service Account key JSON file")
    parser.add_argument("--key_name", required=True, help="name of CAM Deployment Service Account key")
    parser.add_argument("--password", required=True, help="new CAM administrator password")
    parser.add_argument("--reg_code", required=True, help="PCoIP registration code")
    parser.add_argument("--aws_credentials_file", required=False, help="AWS Service Account credentials INI file")

    args = parser.parse_args()

    # Set up session to be used for all subsequent calls to CAM
    session = requests.Session()
    session.verify = False

    print("Setting CAM Administrator password...")
    user, password = get_temp_creds()
    cam_login(user, password)
    password_change(args.password)

    print("Creating CAM deployment...")
    cam_login(user, args.password)
    deployment = deployment_create(args.deployment_name, args.reg_code)
    cam_deployment_key = deployment_key_create(deployment, args.key_name)
    deployment_key_write(cam_deployment_key, args.key_file)

    credentials = parse_aws_sa_key(args.aws_credentials_file)
    username = get_username(credentials)
    if username is not None and validate_aws_credentials(username, credentials):
        print("Registering AWS cloud service account to CAM...")
        deployment_register_service_account(username, credentials, deployment)
    else:
        print("Skipping AWS cloud service account registration to CAM.")