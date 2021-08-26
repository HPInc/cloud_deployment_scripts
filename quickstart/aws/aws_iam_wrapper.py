# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import boto3
from botocore.exceptions import ClientError
import json

sts = boto3.client('sts')

def set_boto3_region(region):
    global iam
    iam = boto3.client('iam', region)


def validate_credentials():
    try:
        sts.get_caller_identity()
        print("Found valid AWS credentials.")
        return True
    except ClientError:
        print("Missing valid AWS credentials.")
        print("See: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration\n")
        return False


def find_user(user_name):
    try:
        iam.get_user(UserName=user_name)
        print(f"Found existing user with the name {user_name}.")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            return False
        raise


def find_role(role_name):
    try:
        iam.get_role(RoleName=role_name)
        print(f"Found existing role with the name {role_name}.")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            return False
        raise


def get_policy_arn(policy_name):
    try:
        account_id = sts.get_caller_identity()['Account']
        return f'arn:aws:iam::{account_id}:policy/{policy_name}'
    except ClientError as e:
        print(e)


def find_policy(policy_name):
    policy_arn = get_policy_arn(policy_name)
    try:
        iam.get_policy(PolicyArn=policy_arn)
        print(f"Found existing policy with the name {policy_name}.")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            return False
        raise


def create_user(user_name):
    print(f"Creating user {user_name}...")
    try:
        user = iam.create_user(UserName=user_name)
        print(f"Successfully created user {user_name}")
    except ClientError as e:
        print(f"Error creating user {user_name}")
        print(e)


def create_role(role_name, account_id, external_id):
    print(f"Creating role {role_name}...")
    trust_document = {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Effect": "Allow",
            "Principal": {
                "AWS": f"arn:aws:iam::{account_id}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                "sts:ExternalId": external_id
                }
            }
            }
        ]
    }
    try:
        role = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_document)
        ).get('Role')
        print(f"Successfully created role {role_name}")
        return role
    except ClientError as e:
        print(f"Error creating role {role_name}")
        print(e)


def create_policy(policy_name, policy_description, policy_document_path):
    print(f"Creating policy {policy_name}...")
    with open(policy_document_path) as json_file:
        policy_document = json.load(json_file)
    try:
        policy = iam.create_policy(
            PolicyName=policy_name, 
            Description=policy_description,
            PolicyDocument=json.dumps(policy_document))
        print(f"Successfully created policy {policy_name}")
        return policy
    except ClientError as e:
        print(f"Error creating policy {policy_name}")
        print(e)


def attach_user_policy(user_name, user_policy_arn):
    print("Attaching policy to user...")
    try:
        iam.attach_user_policy(
            UserName=user_name,
            PolicyArn=user_policy_arn
        )
        print("Successfully attached policy to user")
    except ClientError as e:
        print("Warning: error attaching policy to user")
        print(e)


def attach_role_policy(role_name, role_policy_name):
    print("Attaching policy to role...")
    try:
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn=get_policy_arn(role_policy_name)
        )
        print("Successfully attached policy to role")
    except ClientError as e:
        print("Warning: error attaching policy to role")
        print(e)


def create_access_key(user_name):
    print(f"Creating user access key...")
    try:
        access_key = iam.create_access_key(UserName=user_name).get('AccessKey')
        print(f"Successfully created access key.")
        return access_key
    except ClientError as e:
        print(f"Error creating access key.")
        print(e)


def service_account_create_key(user, sa_key_path):
    print("Creating aws credentials file...")
    
    aws_access_key = create_access_key(user)
    key_data = "[default]\n"
    key_data += f"aws_access_key_id     = {aws_access_key.get('AccessKeyId')}\n"
    key_data += f"aws_secret_access_key = {aws_access_key.get('SecretAccessKey')}"

    with open(sa_key_path, 'w') as keyfile:
        keyfile.write(key_data)

    print(f"Key written to {sa_key_path}")

    return aws_access_key.get('AccessKeyId')

