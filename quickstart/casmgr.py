# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import requests


class CASManager:
    def __init__(self, auth_token, url='https://cam.teradici.com',
                 verify_certificate=True):
        self.auth_token = auth_token
        self.url = url
        self.session = requests.Session()
        # Option to disable verification to avoid validation errors
        # from self-signed certificates as may be used by CAS Manager
        self.session.verify = verify_certificate
        self.session.headers['authorization'] = auth_token

    def deployment_create(self, name, reg_code):
        deployment_details = {
            'deploymentName':   name,
            'registrationCode': reg_code,
        }

        # this is the connector token endpoint
        resp = self.session.post(
            self.url + '/api/v1/deployments',
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

        resp = self.session.post(
            self.url + '/api/v1/auth/users/cloudServiceAccount',
            json = account_details,
        )
        resp.raise_for_status()

    def deployment_key_create(self, deployment, name='sa-key-1'):
        key_details = {
            'deploymentId': deployment['deploymentId'],
            'keyName': name
        }

        # this is the deployment service account endpoint
        resp = self.session.post(
            self.url + '/api/v1/auth/keys',
            json = key_details
        )
        resp.raise_for_status()

        return resp.json()['data']

    def connector_create(self, name, deployment):
        connector_details = {
            'createdBy':     deployment['createdBy'],
            'deploymentId':  deployment['deploymentId'],
            'connectorName': name,
        }

        resp = self.session.post(
            self.url + '/api/v1/auth/tokens/connector',
            json = connector_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def connectors_get(self, deployment):
        resp = self.session.get(
            self.url + '/api/v1/deployments/connectors',
            params = {
                'deploymentId': deployment['deploymentId']
            }
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

        resp = self.session.post(
            self.url + '/api/v1/machines',
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

        resp = self.session.post(
            self.url + '/api/v1/machines/entitlements',
            json = entitlement_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def user_get(self, name, deployment):
        resp = self.session.get(
            self.url + '/api/v1/machines/entitlements/adusers',
            params = {
                'deploymentId': deployment['deploymentId'],
                'name': name,
            },
        )
        resp.raise_for_status()
        resp = resp.json()

        return resp['data'][0] if len(resp.get('data', [])) >= 1 else None

    def machines_get(self, deployment):
        resp = self.session.get(
            self.url + '/api/v1/machines',
            params = {
                'deploymentId': deployment['deploymentId'],
            },
        )
        resp.raise_for_status()

        return resp.json()['data']
