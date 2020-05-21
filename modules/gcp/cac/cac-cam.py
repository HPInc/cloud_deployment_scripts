#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import json
import os
import requests
import sys

API_URL = None


def create_connector_name():
    """A function to create a custom connector name
    
    Uses metadata server to access instance data, which is used to create the connector name.
    
    Returns:
        string: a string for the connector name
    """

    metadata_url = "http://metadata.google.internal/computeMetadata/v1/instance/"
    headers      = {"Metadata-Flavor": "Google"}

    response_zone = requests.get(metadata_url + "zone", headers = headers)
    response_name = requests.get(metadata_url + "name", headers = headers)

    zone = response_zone.text.rpartition('/')[2]
    name = response_name.text

    connector_name = "{}-{}".format(zone, name)

    return connector_name


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
        print("Exception occurred opening CAM Deployment Service Account JSON file. Exiting CAM script...\n{}".format(err))
        raise err

    request_body = dict(username = cam_credentials.get('username'), 
                        password = cam_credentials.get('apiKey'))

    response = requests.post("{}/auth/signin".format(API_URL), json = request_body)

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
        print("Exception occurred opening CAM Deployment Service Account JSON file. Exiting CAM script...\n{}".format(err))
        raise err

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

    response = session.post("{}/auth/tokens/connector".format(API_URL), json=body)

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
