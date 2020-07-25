#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import datetime
import json
import os
import requests
import subprocess
import sys

API_URL = None
METADATA_URL = "http://169.254.169.254/latest/meta-data/"


def create_connector_name():
    """A function to create a custom connector name
    
    Uses metadata server to access instance data, which is used to create the connector name.
    
    Returns:
        string: a string for the connector name
    """

    zone     = requests.get(METADATA_URL + "placement/availability-zone").text
    name     = get_instance_name(zone[:-1])
    iso_time = datetime.datetime.utcnow().isoformat(timespec='seconds').replace(':','').replace('-','') + 'Z'

    connector_name = f"{zone}-{name}-{iso_time}"

    return connector_name


def get_instance_name(region):
    """A function to get the current EC2 instance name
    
    Uses AWS CLI 'describe-tags' to retrieve the current EC2 instance name.
    
    Args:
        region (str): the AWS region to perform 'describe-tags' using AWS CLI
    Returns:
        string: a string for the EC2 instance name
    """

    instance_id   = requests.get(METADATA_URL + "instance-id").text
    filter_string = f"Name=resource-id,Values={instance_id}"

    cmd = f'aws ec2 describe-tags --region {region} --filters {filter_string}'

    instance_tags = subprocess.run(cmd.split(' '),  stdout=subprocess.PIPE).stdout.decode('utf-8')
    instance_tags = json.loads(instance_tags)

    instance_name = instance_tags.get('Tags')[0].get('Value')

    return instance_name


def get_auth_token(filepath):
    """A function to retrieve a CAM authentication token
    
    Uses a CAM Deployment Service Account JSON file to request a CAM authentication token.
    
    Args:
        filepath (str): the location of CAM Deployment Service Account JSON file
    Returns:
        string: a string for the CAM authentication token
    """

    try:
        with open(filepath) as f:
            cam_credentials = json.load(f)

    except Exception as err:
        print("Exception occurred opening CAM Deployment Service Account JSON file. Exiting CAM script...\n")
        raise SystemExit(err)

    request_body = dict(username = cam_credentials.get('username'), 
                        password = cam_credentials.get('apiKey'))

    response = requests.post(f"{API_URL}/auth/signin", json = request_body)

    if not response.status_code == 200:
        raise Exception(response.text)

    response_body = response.json()
    auth_token    = response_body.get('data').get('token')

    return auth_token


def get_deployment_id(filepath):
    """A function to parse the deployment ID
    
    Parses the deployment ID from the CAM Deployment Service Account JSON file.
    
    Args:
        filepath (str): the location of CAM Deployment Service Account JSON file
    Returns:
        string: a string for the deployment ID
    """

    try:
        with open(filepath) as f:
            cam_credentials = json.load(f)

    except Exception as err:
        print("Exception occurred opening CAM Deployment Service Account JSON file. Exiting CAM script...\n")
        raise SystemExit(err)

    return cam_credentials.get('deploymentId')


def get_cac_token(auth_token, deployment_id, connector_name):
    """A function to create a connector token
    
    Creates a connector token using the authentication token and deployment ID.
    
    Args:
        auth_token (str)    : auth_token created using CAM Deployment Service Account
        deployment_id (str) : a string for the deployment ID
    	connector_name (str): a string for the connector name
    Returns:
        string: a string for the connector token
    """

    session = requests.Session()
    session.headers.update({"Authorization": auth_token})

    body = dict(deploymentId  = deployment_id, 
                connectorName = connector_name)

    response = session.post(f"{API_URL}/auth/tokens/connector", json=body)

    if not response.status_code == 200:
        raise Exception(response.text)

    response_body   = response.json()
    connector_token = response_body.get('data').get('token')

    return connector_token


def main():
    parser = argparse.ArgumentParser(description="This script uses CAM Deployment Service Account JSON file to create a new connector token.")

    parser.add_argument("cam", help="specify the path to CAM Deployment Service Account JSON file")
    parser.add_argument("--url", default="https://cam.teradici.com/api/v1", help="specify the api url")
    args = parser.parse_args()

    # Allow user to override default CAM URL
    global API_URL
    API_URL = args.url

    auth_token     = get_auth_token(args.cam)
    deployment_id  = get_deployment_id(args.cam)
    connector_name = create_connector_name()
    cac_token      = get_cac_token(auth_token, deployment_id, connector_name)

    return cac_token


if __name__ == '__main__':
    try:
        # Print the cac_token string as the output of this script
        print(main())

    except:
        # Prevent bash from interpreting any error messages
        sys.exit(1)
