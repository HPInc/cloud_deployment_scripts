#!/usr/bin/env python3

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import aws_iam_wrapper as aws
import boto3
import casmgr
import getpass
import json
import math
import re
import sys
import textwrap

DEFAULT_REGION      = "us-west-1"
DEFAULT_NUMBEROF_WS = 0
DEFAULT_PREFIX      = "quick"

# Machine name and metric specs
MACHINE_PROPERTIES_JSON = "aws-machine-properties.json"

# The number of available IP address in subnet. To see reserved IPs, please
# see: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#VPC_Sizing
MAX_SUBNET_IPS = 239

SERVICE_QUOTA_REQUIREMENTS = {
    'vpc': {
        "IPv4 CIDR blocks per VPC": 1,
        "Inbound or outbound rules per security group": 3,
        "Internet gateways per Region": 1,
        "NAT gateways per Availability Zone": 1,
        "Route tables per VPC": 2,
        "Routes per route table": 2,
        "Security groups per network interface": 4,
        "VPC security groups per Region": 5,
        "Subnets per VPC": 3,
        "VPCs per Region": 1,
        "Network interfaces per Region": 3
    },
    'ec2': {
        "EC2-VPC Elastic IPs": 1,
        "All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests": 0,
        "All G Spot Instance Requests": 0
    }
}

def configurations_get(ws_types, username, quickstart_path):
    # AWS EC2 Client
    ec2 = boto3.client('ec2')

    # TODO: Dynamically read the vars.tf terraform file instead
    with open(f"{quickstart_path}{MACHINE_PROPERTIES_JSON}", 'r') as f:
        machine_properties = json.load(f)

    def reg_code_get(order_number):
        print(f"{order_number}.  Please enter your PCoIP Registration Code.")
        print("    If you don't have one, visit: https://www.teradici.com/compare-plans.")
        while True:
            reg_code = input("reg_code: ").strip()
            if re.search(r"^[0-9A-Z]{12}@([0-9A-F]{4}-){3}[0-9A-F]{4}$", reg_code, re.IGNORECASE):
                return reg_code
            print("Invalid PCoIP Registration Code format (Ex. ABCDEFGHIJKL@0123-4567-89AB-CDEF). Please try again.")

    def api_token_get(order_number):
        print(f"{order_number}.  Please enter the CAS Manager API token.")
        print("    Log into https://cas.teradici.com, click on your email address on the top right and select \"Get API token\".")
        while True:
            api_token = input("api_token: ").strip()
            mycasmgr = casmgr.CASManager(api_token)
            print("Validating API token with CAS Manager... ", end="")
            if (mycasmgr.auth_token_validate()):
                print("Yes")
                return api_token
            print("\nInvalid CAS Manager API token. Please try again.")

    # Gets the available quota for each service quota
    def service_quota_get(aws_region):
        # Set the API client region
        service_quota = boto3.client('service-quotas', aws_region)
        available_service_quota = {}
        for service in SERVICE_QUOTA_REQUIREMENTS:
            # This returns a dictionary object where one of the items with information such
            # as the applied value of each quota that matches the service code (ex. vpc, ec2) 
            service_quota_list = service_quota.list_service_quotas(
                ServiceCode=service,
                MaxResults=100
            )['Quotas']
            available_service_quota[service] = { r: q['Value'] for q in service_quota_list for r in SERVICE_QUOTA_REQUIREMENTS[service] if r == q['QuotaName'] }
        return available_service_quota

    def service_quota_print(aws_region):
        available_service_quota = service_quota_get(aws_region)
        for service in available_service_quota:
            print(f"\nYour applied {service} service quotas for region {aws_region}")
            print("{:<75} {:<20}".format('SERVICE', 'QUOTA'))
            for r in available_service_quota[service]:
                print("{:<75} {:<20}".format(r, available_service_quota[service][r]))

    def service_quota_reserve(aws_region, requirements):
        if not requirements_are_met(aws_region, requirements):
            return False
        for service in requirements:
            for r in requirements[service]:
                required_service_quota[service][r] += requirements[service][r]
        return True

    # Print options 1,2,3... and ask for a number input
    def number_option_get(options, text):
        options.sort()
        for i in range(len(options)):
            print("       {:<4} {:<50}".format(f"[{i+1}]", options[i]))
        while True:
            try:
                selection = int(input(f"       {text}: ").strip())
                if selection > 0:
                    return options[selection-1]  
                raise IndexError
            except (ValueError, IndexError):
                print(f"       Please enter a valid option (Ex. 1).")

    def region_get(order_number):
        aws_region_resource_list = ec2.describe_regions()['Regions']
        aws_regions_list = [r['RegionName'] for r in aws_region_resource_list]
        print(f"    {order_number}. Please enter the region to deploy in.")
        return number_option_get(aws_regions_list, "aws_region")

    def region_requirements_met(aws_region):
        print(f"    Getting your service quota for region {aws_region}...")
        # service_quota_print(aws_region)
        if not service_quota_reserve(aws_region, SERVICE_QUOTA_REQUIREMENTS):
            return False
        for machine in ["cac", "dc"]:
            if not service_quota_reserve(aws_region, machine_properties[machine]["service_requirements"]):
                return False
        return True

    def requirements_are_met(aws_region, requirements):
        available_service_quota = service_quota_get(aws_region)
        error_response = "    Based on your applied service quota, not taking into account quotas that are already in use..." # additional information will be appended if any limit is reached
        limit_exceeded = False
        for service in requirements:
            for r in requirements[service]:
                if required_service_quota[service][r] + requirements[service][r] > available_service_quota[service][r]:
                    error_response += f"\n      Required {required_service_quota[service][r] + requirements[service][r]} {r} but only {available_service_quota[service][r]} allowed."
                    limit_exceeded = True
        if limit_exceeded:
            print(error_response)
            print("      To request to increase the quota, please see: https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html")
            return False
        return True

    def numberof_ws_get(index, aws_region, machine):

        def set_to_zero(reason):
            print(f"    {chr(index)}. {reason}")
            print(f"       Setting {machine_properties[machine]['name']} ({machine}) to 0...")

        # The number of workstations requested can't exceed the number of available IP address in the subnet
        max_numberof_ws = MAX_SUBNET_IPS - ws_count
        # Skip the prompt and set value to 0 if no more IP address is available in the subnet
        if max_numberof_ws <= 0:
            set_to_zero("There are no more available IP address in the 10.0.2.0/24 subnet.")
            return 0

        # Calculate the maximum number of workstations the user can request with the available service quota
        available_service_quota = service_quota_get(aws_region)
        ws_service_req = machine_properties[machine]['service_requirements']
        for service in ws_service_req:
            for r in ws_service_req[service]:
                remaining_service_quota = available_service_quota[service][r] - required_service_quota[service][r]
                max_numberof_ws = min(remaining_service_quota / ws_service_req[service][r], max_numberof_ws)
        max_numberof_ws = math.floor(max_numberof_ws)
        # Skip the prompt and set value to 0 if there's no more quota left
        if max_numberof_ws <= 0:
            set_to_zero(f"You don't have enough service quota to deploy any {machine_properties[machine]['name']}.")
            return 0

        while True:
            try:
                number = int(input(f"    {chr(index)}. Number of {machine_properties[machine]['name']} ({machine}): ").strip() or DEFAULT_NUMBEROF_WS)
                if (number < 0):
                    raise ValueError
                requirements = { service: { r: ws_service_req[service][r]*number for r in ws_service_req[service] } for service in ws_service_req }
                if (number <= max_numberof_ws):
                    if service_quota_reserve(aws_region, requirements):
                        return number
                    continue
                if requirements_are_met(aws_region, requirements):
                    print(f"       There are only {max_numberof_ws} available IP addresses in the 10.0.2.0/24 subnet. ", end="")
                print("    ", end ="")
            except ValueError:
                print("       Invalid number input. ", end="")
            print("Please try again.")

    def prefix_get(aws_region):
        aws.set_boto3_region(aws_region)
        while True:
            prefix = input("prefix: ").strip() or DEFAULT_PREFIX
            if (len(prefix) > 5):
                print("Maximum 5 characters to avoid cropping of workstation hostnames. Please try again.")
                continue
            print('Checking that the AWS resources names are unique...')
            aws_username = prefix + '-cas-manager'
            aws_role_name = f'{aws_username}_role'
            role_policy_name = f'{aws_role_name}_policy'
            if any((aws.find_user(aws_username), aws.find_role(aws_role_name), aws.find_policy(role_policy_name))):
                print("AWS IAM resources must have unique names. Please try again.")
                continue
            print("Yes")
            return prefix

    def answer_is_yes(prompt):
        while True:
            response = input(prompt).lower()
            if response in ('y', 'yes'):
                return True
            if response in ('n', 'no'):
                return False

    def ad_password_get(username):
        txt = r'''
        Please enter a password for the Active Directory Administrator.

        Note Windows passwords must be at least 7 characters long and meet complexity
        requirements:
        1. Must not contain user's account name or display name
        2. Must have 3 of the following categories:
        - a-z
        - A-Z
        - 0-9
        - special characters: ~!@#$%^&*_-+=`|\(){}[]:;"'<>,.?/
        - unicode characters
        See: https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
        '''
        print(textwrap.dedent(txt))

        while True:
            password1 = getpass.getpass('Enter a password: ').strip()
            if not ad_password_validate(password1, username):
                print("Please try again.")
                continue
            password2 = getpass.getpass('Re-enter the password: ').strip()
            if password1 == password2:
                break
            print(f'The passwords do not match. Please try again.')
        print('')

        return password1

    def ad_password_validate(password, username):
        # delimeters are specified in the microsoft documentation
        username_parsed = re.split("[—,.\-\_#\s\t]", username)
        for u in username_parsed:
            if len(u) < 3:
                continue
            if re.search(u, password, re.IGNORECASE):
                print("Password cannot contain username.", end=' ')
                return False

        if len(password) < 7:
            print("Password must be at least 7 characters long.", end=' ')
            return False

        count = 0

        # check lowercase, uppercase, digits, special characters
        checks = ["[a-z]", "[A-Z]", "\d", "[@$!%*#?&]"]
        for regex in checks:
            if re.search(regex, password):
                count += 1

        # check unicode: if the password contains unicode characters, 
        # it will change when encoded to utf-8 to one of [\u00d8-\u00f6]
        if f'b\'{password}\'' != f'{password.encode("utf-8")}':
            count += 1

        if (count > 2):
            return True
        print("Password does not meet the complexity requirements.", end=' ')
        return False

    # Get configurations while loop
    while True:
        # Local shared variables
        cfg_data = {} # Dictionary that will be returned
        ws_count = 0 # Variable to keep track of workstations count

        cfg_data['reg_code'] = reg_code_get("1")
        print("\n")

        cfg_data['api_token'] = api_token_get("2")
        print("\n")

        print(f"3.  The default region is {DEFAULT_REGION}.")
        customize = not answer_is_yes("    Would you like to continue with the default selections (y/n)? ")

        while True:
            required_service_quota = { 
                'vpc': { r: 0 for r in SERVICE_QUOTA_REQUIREMENTS['vpc'] },
                'ec2': { r: 0 for r in SERVICE_QUOTA_REQUIREMENTS['ec2'] }
            } # Dictionary to keep track of reserved service quota

            if customize:
                print("")
                print("    Getting AWS regions list...")
                print("")
                cfg_data['aws_region'] = region_get("a")
                print("")
            else:
                cfg_data['aws_region'] = DEFAULT_REGION

            if region_requirements_met(cfg_data['aws_region']):
                break
            if not answer_is_yes("    Try another region (y/n)? "):
                print("\nExiting script...")
                sys.exit(1)
            customize = True

        print("\n")
        print(f"4.  Please enter the number of remote workstations to create (Default: {DEFAULT_NUMBEROF_WS}).")
        index = ord('a')
        for machine in ws_types:
            print("")
            cfg_data[machine] = numberof_ws_get(index, cfg_data['aws_region'], machine)
            ws_count += cfg_data[machine]
            index += 1

        print("\n")
        print(f"5.  Add a prefix for the names of your IAM resources (Maximum 5 characters. Default: {DEFAULT_PREFIX}).")
        cfg_data['prefix'] = prefix_get(cfg_data['aws_region'])
        print("\n")

        print("#######################################")
        print("# Please review your selections below #")
        print("#######################################")
        print("{:<10} {:<10}".format('VARIABLE', 'VALUE'))
        for variable, value in cfg_data.items():
            print("{:<10} {:<10}".format(variable, value))

        if not answer_is_yes("\nWould you like to proceed with your selections (y/n)? "):
            print("\n") 
            continue # back to the beginning of the get configurations while loop

        print("")
        cfg_data['ad_password'] = ad_password_get(username)
        return cfg_data # Return to quickstart executable script
