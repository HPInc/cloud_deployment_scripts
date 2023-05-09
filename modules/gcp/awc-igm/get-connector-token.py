#!/usr/bin/env python3

# © Copyright 2022 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import datetime
import distutils.version
import json
import requests


def create_connector_name():
    """A function to create a custom connector name
    
    Uses metadata server to access instance data, which is used to create the connector name.
    
    Returns:
        string: a string for the connector name
    """

    metadata_url = "http://metadata.google.internal/computeMetadata/v1/instance/"
    headers      = {"Metadata-Flavor": "Google"}
    iso_time     = datetime.datetime.utcnow().isoformat(timespec='seconds').replace(':','').replace('-','') + 'Z'

    response_zone = requests.get(metadata_url + "zone", headers = headers)
    response_name = requests.get(metadata_url + "name", headers = headers)

    zone = response_zone.text.rpartition('/')[2]
    name = response_name.text

    connector_name = f"{zone}-{name}-{iso_time}"

    return connector_name


def load_service_account_key(path):
    print(f"Loading Anyware Manager deployment service account key from {path}...")

    with open(path) as f:
        dsa_key = json.load(f)

    return dsa_key


def awm_login(key):
    print(f"Signing in to Anyware Manager with key {key['keyName']}...")

    payload = {
        'username': key['username'], 
        'password': key['apiKey'],
    }
    resp = session.post(
        f"{awm_api_url}/auth/signin",
        json=payload, 
    )
    resp.raise_for_status()

    token = resp.json()['data']['token']
    session.headers.update({"Authorization": token})


def get_awc_token(key, connector_name):
    print(f"Creating a connector token in deployment {key['deploymentId']}...")

    payload = {
        'deploymentId': key['deploymentId'], 
        'connectorName': connector_name,
    }
    resp = session.post(
        f"{awm_api_url}/auth/tokens/connector",
        json=payload, 
    )
    resp.raise_for_status()

    return resp.json()['data']['token']


def token_write(token, path):
    print(f"Writing connector token to {path}...")
    with open(path, 'w') as f:
        f.write(token)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="This script uses Anyware Manager Deployment Service Account JSON file to create a new connector token.")

    parser.add_argument("awm", help="specify the path to Anyware Manager Deployment Service Account JSON file")
    parser.add_argument("--out", required=True, help="File to write the connector token")
    parser.add_argument("--url", default="https://cas.teradici.com", help="specify the api url")
    parser.add_argument("--insecure", action="store_true", help="Allow unverified HTTPS connection to Anyware Manager")

    args = parser.parse_args()

    awm_api_url = f"{args.url}/api/v1"

    # Set up session to be used for all subsequent calls to Anyware Manager
    session = requests.Session()
    if args.insecure:
        session.verify = False

    try:
        retry_strategy = requests.adapters.Retry(
            total=10,
            backoff_factor=1,
            status_forcelist=[500,502,503,504],
            allowed_methods=["POST", "GET"]
        )
    except TypeError as e:
        # Older versions of urllib3 use method_whitelist instead of allowed_methods
        installed_version = distutils.version.StrictVersion(requests.urllib3.__version__)
        changed_version = distutils.version.StrictVersion("1.26.0")
        if installed_version < changed_version:
            retry_strategy = requests.adapters.Retry(
                total=10,
                backoff_factor=1,
                status_forcelist=[500,502,503,504],
                method_whitelist=["POST", "GET"]
            )
        else:
            raise e
    session.mount("https://", requests.adapters.HTTPAdapter(max_retries=retry_strategy))

    dsa_key = load_service_account_key(args.awm)
    awm_login(dsa_key)
    connector_name = create_connector_name()
    awc_token = get_awc_token(dsa_key, connector_name)
    token_write(awc_token, args.out)
