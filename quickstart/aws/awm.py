# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import requests
import retry
from retry import retry


class AnywareManager:
    def __init__(self, auth_token, url='https://cas.teradici.com'):
        self.auth_token = auth_token
        self.url = url
        self.header = {'authorization': auth_token}

    def auth_token_validate(self):
        resp = requests.post(
            self.url + '/api/v1/auth/verify',
            headers = self.header
        )
        try:
            resp.raise_for_status()
            return True
        except requests.models.HTTPError:
            if resp.status_code == 401:
                return False
            raise

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

    def deployment_key_create(self, deployment, name='sa-key-1'):
        key_details = {
            'deploymentId': deployment['deploymentId'],
            'keyName': name
        }

        # this is the deployment service account endpoint
        resp = requests.post(
            self.url + '/api/v1/auth/keys',
            headers = self.header,
            json = key_details
        )
        resp.raise_for_status()

        return resp.json()['data']

    def deployment_signin(self, awm_deployment_key):
        account_details = {
            'username': awm_deployment_key['username'],
            'apiKey': awm_deployment_key['apiKey']
        }
        resp = requests.post(
            self.url + '/api/v1/auth/signin',
            json = account_details
        )
        resp.raise_for_status()
        
        self.auth_token = resp.json()['data']['token']
        self.header = {'authorization': self.auth_token}

    def machine_add_existing(self, name, deployment, region):
        instance_id = self.instance_id_get(deployment, region, name)[0]
        machine_details = {
            'machineName':  name,
            'deploymentId': deployment['deploymentId'],
            'provider':     'aws',
            'instanceId':   instance_id,
            'region':       region,
        }

        resp = requests.post(
            self.url + '/api/v1/machines',
            headers = self.header,
            json = machine_details,
        )
        resp.raise_for_status()

        return resp.json()['data']

    def generate_aws_role_info(self, deployment):
        deployment_id = deployment['deploymentId']
        resp = requests.get(
            self.url + f'/api/v1/deployments/{deployment_id}/cloudServiceAccounts/awsRole',
            headers = self.header,
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

    #Might need a few tries before successfully registered
    @retry(tries=5,delay=5)
    def deployment_add_aws_account(self, deployment, role_arn):
        deployment_id = deployment['deploymentId']
        payload = {
            'provider': 'aws',
            'credential': {
                'roleArn': role_arn
            }
        }
        resp = requests.post(
            self.url + f'/api/v1/deployments/{deployment_id}/cloudServiceAccounts',
            headers = self.header,
            json = payload,
        )
        #Solving the 412 Client Error is what the retry is for
        resp.raise_for_status()

    def list_instances(self, deployment, region):
        resp = requests.get(
            self.url + f'/api/v1/machines/cloudproviders/aws/instances',
            headers = self.header,
            params = {
                'deploymentId': deployment['deploymentId'],
                'region':       region,
            }
        )
        resp.raise_for_status()
        
        return resp.json()['data']

    def instance_id_get(self, deployment, region, instance_name):
        instances = self.list_instances(deployment, region)
        return [i['instanceId'] for i in instances if i['instanceName'] == instance_name]

