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
MAX_SUBNET_IPS = 251

# These requirements were determined by deploying a single connector deployment to
# see how each ec2 and vpc resources are used. Please see: 
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-resource-limits.html
SERVICE_QUOTA_REQUIREMENTS = {
    'vpc': {
        "Internet gateways per Region": 1,
        "NAT gateways per Availability Zone": 1,
        "VPC security groups per Region": 5,
        "VPCs per Region": 1,
        "Network interfaces per Region": 3
    },
    'ec2': {
        "EC2-VPC Elastic IPs": 1,
        "All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests": 0,
        "All G Spot Instance Requests": 0
    }
}

# Name of the quota mapped to the function call to get the number of quota
# that is currently in use and the name of the list within the response 
# that contains the resources currently in use
QUOTA_CHECK_MAPPING = {
    'Internet gateways per Region': {
        'function': 'ec2.describe_internet_gateways',
        'query': 'InternetGateways'
    },
    'NAT gateways per Availability Zone': {
        'function': 'ec2.describe_nat_gateways',
        'query': 'NatGateways'
    },
    'VPC security groups per Region': {
        'function': 'ec2.describe_security_groups',
        'query': 'SecurityGroups'
    },
    'VPCs per Region': {
        'function': 'ec2.describe_vpcs',
        'query': 'Vpcs'
    },
    'Network interfaces per Region': {
        'function': 'ec2.describe_network_interfaces',
        'query': 'NetworkInterfaces'
    },
    'EC2-VPC Elastic IPs': {
        'function': 'ec2.describe_addresses',
        'query': 'Addresses'
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
            print("Validating API token with CAS Manager...", end="")
            if (mycasmgr.auth_token_validate()):
                print("Yes")
                return api_token
            print("\nInvalid CAS Manager API token. Please try again.")

    def service_quota_in_use_get(requirement, aws_region):
        """AWS keeps track of the service quota limits, but to get the service quota usage, this function
        makes different API calls based on the service quota and handles the response accordingly.

        Args:
            requirement (str): name of service quota requirement
            aws_region (str): name of AWS region

        Returns:
            count (int): number of resources used for the requirement and in the region specified
        """
        def instance_requests_count(pattern):
            """AWS keeps track of the number of vCPUs in use for each instance types. This function counts the 
            total vCPUs that are used for the specified instance request service quota requirement, which could 
            include multiple instance types.

            Args:
                pattern (list of char): instance types included in the instance request service quota requirement

            Returns:
                count (int): number of vCPUs in use for the instance request service quota requirement from all API responses
            """
            def vCPUs_count():
                """This functions retrieves the list of instances currently deployed in the region, which is the Reservations list, 
                and gets the instance type of each instance found, then matches the first character to the pattern (i.e. the first 
                letter of instance type t2.xlarge is 't' and the pattern is a list of characters that could include 't'). If it is 
                a match, it will then retrieve the vCPUs that is used by that instance type and add it to the count.

                Returns:
                    count (int): the number of vCPUs in use for the instance request quota from one API call response
                """
                count = 0
                for i in response['Reservations']:
                    instance_type = i['Instances'][0]['InstanceType']
                    if instance_type[0] in pattern:
                        count += ec2.describe_instance_types(InstanceTypes=[instance_type])['InstanceTypes'][0]['VCpuInfo']['DefaultVCpus']
                return count

            count = 0
            response = ec2.describe_instances()
            try:
                count += vCPUs_count()
                while response['NextToken']:
                    response = ec2.describe_instances(
                        NextToken=response['NextToken']
                    )
                    count += vCPUs_count(response['Reservations'][0])
            except (IndexError, KeyError):
                pass
            return count

        ec2 = boto3.client('ec2', aws_region)

        if requirement == "All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests":
            return instance_requests_count(['a','c','d','h','i','m','r','t','z'])
        if requirement == "All G Spot Instance Requests":
            return instance_requests_count(['g'])

        for quota_name in QUOTA_CHECK_MAPPING:
            if requirement != quota_name:
                continue
            function = QUOTA_CHECK_MAPPING[quota_name]['function']
            query = QUOTA_CHECK_MAPPING[quota_name]['query']
            response = eval(function + "()")
            count = len(response[query])
            try:
                while response['NextToken']:
                    response = eval(function + f"(NextToken={response['NextToken']})")
                    count += len(response[query])
            except KeyError:
                pass
            return count

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
            available_service_quota[service] = {}
            for r in SERVICE_QUOTA_REQUIREMENTS[service]:
                for q in service_quota_list:
                    if r == q['QuotaName']:
                        available_service_quota[service][r] = q['Value'] - service_quota_in_use_get(r, aws_region)
        return available_service_quota

    def service_quota_reserve(aws_region, requirements, verbose=True):
        if not requirements_are_met(aws_region, requirements, verbose):
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
        print(f"    Checking that you have enough service quota required for this deployment...", end="")
        if not service_quota_reserve(aws_region, SERVICE_QUOTA_REQUIREMENTS):
            return False
        for machine in ["cac", "dc"]:
            print(f"    Checking that you have enough service quota to deploy the {machine_properties[machine]['name']}...", end="")
            if not service_quota_reserve(aws_region, machine_properties[machine]["service_requirements"]):
                return False
        return True

    def requirements_are_met(aws_region, requirements, verbose=True):

        def verbose_print(text):
            if verbose:
                print(text, end="")

        available_service_quota = service_quota_get(aws_region)
        error_response = ""
        limit_exceeded = False
        for service in requirements:
            for r in requirements[service]:
                remaining_service_quota = available_service_quota[service][r] - required_service_quota[service][r]
                if requirements[service][r] > remaining_service_quota:
                    # For clarity (ex. Required 4 vCPUs for All G Spot Instance Requests but only 2 allowed)
                    if "Spot Instance Requests" in r:
                        error_response += f"    Required {requirements[service][r]} vCPUs for {r} but only {remaining_service_quota} allowed.\n"
                    else:
                        error_response += f"    Required {requirements[service][r]} {r} but only {remaining_service_quota} allowed.\n"
                    limit_exceeded = True
        if limit_exceeded:
            verbose_print(f"No\n{error_response}")
            verbose_print("    To request to increase the quota, please see: https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html \n")
            return False
        verbose_print("Yes\n")
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

        print(f"    {chr(index)}. You can have up to {max_numberof_ws} {machine_properties[machine]['name']} workstations.")            
        while True:
            try:
                number = int(input(f"       Number of {machine_properties[machine]['name']} ({machine}): ").strip() or DEFAULT_NUMBEROF_WS)
                if (number < 0):
                    raise ValueError
                requirements = { service: { r: ws_service_req[service][r]*number for r in ws_service_req[service] } for service in ws_service_req }
                if (number <= max_numberof_ws):
                    print("       ", end="")
                    if service_quota_reserve(aws_region, requirements, verbose=False):
                        return number
                print(f"    Checking that you have enough service quotas to deploy {number} {machine_properties[machine]['name']}...", end="")
                if requirements_are_met(aws_region, requirements, verbose=True):
                    print(f"    There are only {max_numberof_ws} available IP addresses in the 10.0.2.0/24 subnet.")
                print("    ", end="")
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
            print('Checking that the AWS IAM resources names are unique...')
            aws_username = prefix + '-cas-manager'
            aws_role_name = f'{aws_username}_role'
            role_policy_name = f'{aws_role_name}_policy'
            if any((aws.find_user(aws_username), aws.find_role(aws_role_name), aws.find_policy(role_policy_name))):
                print("AWS IAM resources must have unique names. Please try again.")
                continue
            print("Great, this prefix is unique!")
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
            else:
                cfg_data['aws_region'] = DEFAULT_REGION

            print("")
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
