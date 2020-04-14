# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import requests


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
        resp = requests.post(
            self.url + '/api/v1/deployments',
            headers = self.header,
            json = deployment_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

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

        resp = requests.post(
            self.url + '/api/v1/auth/users/cloudServiceAccount',
            headers = self.header,
            json = account_details,
        )
        resp.raise_for_status()

    def deployment_key_create(self, deployment):
        deployment_id = {
            'deploymentId': deployment['deploymentId']
        }

        # this is the deployment service account endpoint
        resp = requests.post(
            self.url + '/api/v1/auth/keys',
            headers = self.header,
            json = deployment_id,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def connector_create(self, name, deployment):
        connector_details = {
            'createdBy':     deployment['createdBy'],
            'deploymentId':  deployment['deploymentId'],
            'connectorName': name,
        }

        resp = requests.post(
            self.url + '/api/v1/auth/tokens/connector',
            headers = self.header,
            json = connector_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def machine_add_existing(self, name, project_id, zone, deployment):
        machine_details = {
            'provider':    'gcp',
            'machineName':  name,
            'deploymentId': deployment['deploymentId'],
            'projectId':    project_id,
            'zone':         zone,
            'active':       True,
            'managed':      True,
        }

        resp = requests.post(
            self.url + '/api/v1/machines',
            headers = self.header,
            json = machine_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def entitlement_add(self, user, machine):
        entitlement_details = {
            'machineId': machine['machineId'],
            'deploymentId': machine['deploymentId'],
            'userGuid': user['userGuid'],
        }

        resp = requests.post(
            self.url + '/api/v1/machines/entitlements',
            headers = self.header,
            json = entitlement_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def user_get(self, name, deployment):
        resp = requests.get(
            self.url + '/api/v1/machines/entitlements/adusers',
            headers = self.header,
            params = {
                'deploymentId': deployment['deploymentId'],
                'name': name,
            },
        )
        resp.raise_for_status()
        resp = resp.json()

        return resp['data'][0] if len(resp.get('data', [])) >= 1 else None

    def machines_get(self, deployment):
        resp = requests.get(
            self.url + '/api/v1/machines',
            headers = self.header,
            params = {
                'deploymentId': deployment['deploymentId'],
            },
        )
        resp.raise_for_status()

        return resp.json()['data']
