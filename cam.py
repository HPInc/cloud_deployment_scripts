# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import requests
from pprint import pprint

class CloudAccessManager:
    def __init__(self, auth_token, url='https://cam.teradici.com'):
        self.auth_token = auth_token
        self.url = url
        self.header = {'authorization': auth_token}

    def deployment_create(self, name, reg_code):
        deployment_details = {
            'deploymentName':   name,
            'registrationCode': reg_code,
        }

        # this is the connector token endpoint
        new_deployment_resp = requests.post(
            self.url + '/api/v1/deployments',
            headers = self.header,
            json = deployment_details,
        ).json()

        print('Created deployment:')
        pprint(new_deployment_resp)

        return new_deployment_resp['data']

    def deployment_add_gcp_account(self, key, deployment):
        credentials = {
            'clientEmail': key['client_email'],
            'privateKey':  ''.join(key['private_key'].split('\n')[1:-2]),
            'projectId':   key['project_id'],
        }

        account_details = {
            'deploymentId': deployment['deploymentId'],
            'provider':     'gcp',
            'credential':   credentials,
        }

        account_resp = requests.post(
            self.url + '/api/v1/auth/users/cloudServiceAccount',
            headers = self.header,
            json = account_details,
        ).json()

        print('Added GCP account:')
        pprint(account_resp)

        return

    def connector_create(self, name, deployment):
        connector_details = {
            'createdBy':     deployment['createdBy'],
            'deploymentId':  deployment['deploymentId'],
            'connectorName': name,
        }

        new_connector_resp = requests.post(
            self.url + '/api/v1/auth/tokens/connector',
            headers = self.header,
            json = connector_details,
        ).json()

        print('Created connector:')
        pprint(new_connector_resp)

        return new_connector_resp['data']
