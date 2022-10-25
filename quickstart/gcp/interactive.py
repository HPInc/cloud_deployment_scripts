#!/usr/bin/env python3

# Copyright Teradici Corporation 2019-2021;  © Copyright 2021 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import awm
import getpass
import googleapiclient.discovery
import json
import math
import re
import sys
import textwrap

# Name of Compute Engine metrics
METRICS         = [
    "INSTANCES",
    "CPUS",
    "SSD_TOTAL_GB",
    "NVIDIA_P4_VWS_GPUS"
]

# Machine name and metric specs
MACHINE_PROPERTIES_JSON = "gcp-machine-properties.json"

DEFAULT_REGION      = "us-west2"
DEFAULT_ZONE        = "us-west2-b"
DEFAULT_NUMBEROF_WS = "0"
DEFAULT_PREFIX      = "quick"

# The number of available IP address in subnet. To see reserved IPs, please
# see: https://cloud.google.com/vpc/docs/vpc#reserved_ip_addresses_in_every_subnet
MAX_SUBNET_IPS = 250

def configurations_get(project_id, ws_types, username):
    # GCP Compute Engine API
    cpe_service = googleapiclient.discovery.build('compute', 'v1')

    # TODO: Dynamically read the vars.tf terraform file instead
    with open(MACHINE_PROPERTIES_JSON, 'r') as f:
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
        print(f"{order_number}.  Please enter the Anyware Manager API token.")
        print("    Log into https://cas.teradici.com, click on your email address on the top right and select \"Get API token\".")
        while True:
            api_token = input("api_token: ").strip()
            my_awm = awm.AnywareManager(api_token)
            print("Validating API token with Anyware Manager... ", end="")
            if (my_awm.auth_token_validate()):
                print("Yes")
                return api_token
            print("\nInvalid Anyware Manager API token. Please try again.")

    def region_resource_list_get(gcp_region):
        # This returns a dictionary object which contains information about the
        # compute engine quota and zones for each matching region. Please see: 
        # https://cloud.google.com/compute/docs/reference/rest/v1/regions/list
        return cpe_service.regions().list(
            project=project_id,
            filter=f'name={gcp_region}'
        ).execute()

    # Gets the available quota for each Compute Engine metric
    def cpe_quota_get(gcp_region):
        print(f"\nGetting your Compute Engine quota for region {gcp_region}...")
        quotas = region_resource_list_get(gcp_region)['items'][0]['quotas']
        # The available quota equals quota limit minus quota usage
        return { m: q['limit'] - q['usage'] for q in quotas for m in METRICS if q['metric'] == m }

    # Prints the remaining available quota in a table format
    def cpe_quota_print(gcp_region):
        print(f"\nYour remaining Compute Engine quotas for region {gcp_region}")
        print("{:<20} {:<20}".format('METRIC', 'QUOTA'))
        for m in METRICS:
            remaining_available_cpe_quota = available_cpe_quota[m] - required_cpe_quota[m]
            print("{:<20} {:<20}".format(m, remaining_available_cpe_quota))
        print("")

    # Updates the required_cpe_quota list to show keep track of how much quota
    # will be needed to create the CAC, DC, and workstations instances 
    def cpe_quota_reserve(machine, number, gcp_region, gcp_zone):
        if not requirements_are_met(machine, number, gcp_region, gcp_zone, print_cpe_report=False):
            return
        for m in METRICS:
            required_cpe_quota[m] += number * machine_properties[machine]['spec'][m]

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
        region_resource_list = region_resource_list_get("*")['items']
        gcp_regions_list = [ r['name'] for r in region_resource_list ]
        print(f"    {order_number}. Please enter the region to deploy in.")
        return number_option_get(gcp_regions_list, "gcp_region")

    def region_requirements_met(gcp_region):
        # Check that there's at least enough regional quota to deploy CAC and DC
        for machine in ["cac","dc"]:
            # Not checking accelerator availability here so gcp_zone can be anything
            if requirements_are_met(machine, 1, gcp_region, gcp_zone=""):
                cpe_quota_reserve(machine, 1, gcp_region, gcp_zone="")
                continue
            if not answer_is_yes("Try another region (y/n)? "):
                print("Exiting script...")
                sys.exit(1)
            return False
        return True

    def zone_get(order_number, gcp_region):
        region_resource_list = region_resource_list_get(gcp_region)
        gcp_zones_list = [ z.split("/")[-1] for z in region_resource_list['items'][0]['zones'] ]
        print(f"    {order_number}. Please select from one of the following zones:")
        return number_option_get(gcp_zones_list, "gcp_zone")

    # Returns True if there's enough compute engine quota and the GPU accelerator is available.
    # print_cpe_report == True means print Compute Engine quota report
    # print_gpu_report == True means print accelerator availability report
    def requirements_are_met(machine, number, gcp_region, gcp_zone, print_cpe_report=True, print_gpu_report=False):
        # Check Compute Engine quota
        def verbose1(text):
            if print_cpe_report:
                print(text,end="")

        error_response = "No" # additional information will be appended if any limit is reached
        limit_exceeded = False
        verbose1(f"Checking if Compute Engine quotas are available for {number} {machine_properties[machine]['name']}... ")
        for m in METRICS:
            if (machine_properties[machine]['spec'][m] == 0):
                continue
            quota_required = number * machine_properties[machine]['spec'][m]
            remaining_available_cpe_quota = available_cpe_quota[m] - required_cpe_quota[m]
            if (remaining_available_cpe_quota >= quota_required):
                continue
            error_response += f"\nYou have reached the limit for number of resource {m} for this project. "
            error_response += f"(Required {quota_required} {m}, {machine_properties[machine]['spec'][m]} for each workstation.)"
            limit_exceeded = True
        if limit_exceeded and print_cpe_report:
            verbose1(f"{error_response}\n")
            cpe_quota_print(gcp_region)
            verbose1("To request to increase the quota, please see: https://console.cloud.google.com/iam-admin/quotas. ")
            return False
        verbose1("Yes\n")

        # Check accelerator availability
        def verbose2(text):
            if print_gpu_report:
                print(text,end="")

        accelerator_name = machine_properties[machine]['accelerator']
        if accelerator_name == "":
            return True
        accelerator_resource = cpe_service.acceleratorTypes().list(
            project=project_id, 
            zone=gcp_zone,
            filter=f"name={accelerator_name}"
        ).execute()
        verbose2(f"Checking availaibility of accelerator {accelerator_name} for {machine_properties[machine]['name']} ({machine}) in zone {gcp_zone}... ")
        if "items" in accelerator_resource.keys():
            verbose2("Yes\n")
            return True
        verbose2("No")
        verbose2(f"\n  You will not be able to deploy any {machine_properties[machine]['name']} in this zone.")
        verbose2("\n  To check the availability, see: https://cloud.google.com/compute/docs/gpus/gpu-regions-zones.\n")
        return False

    def numberof_ws_get(index, machine, gcp_region, gcp_zone):

        def set_to_zero(reason):
            print(f"    {chr(index)}. {reason}")
            print(f"       Setting {machine_properties[machine]['name']} ({machine}) to 0...")

        # Skip the prompt and set value to 0 if the accelerator is not available
        if not requirements_are_met(machine, 0, gcp_region, gcp_zone, print_cpe_report=False):
            set_to_zero("The GPU accelerator is not available.")
            return 0

        # The number of workstations requested can't exceed the number of available IP address in the subnet
        max_numberof_ws = MAX_SUBNET_IPS - ws_count
        # Skip the prompt and set value to 0 if no more IP address is available in the subnet
        if max_numberof_ws <= 0:
            set_to_zero("There are no more available IP address in the 10.0.2.0/24 subnet.")
            return 0

        # Calculate the maximum number of workstations the user can request with the available quota
        for m in METRICS:
            if (machine_properties[machine]['spec'][m] != 0):
                remaining_available_cpe_quota = available_cpe_quota[m] - required_cpe_quota[m]
                max_numberof_ws = min(remaining_available_cpe_quota / machine_properties[machine]['spec'][m], max_numberof_ws)
        max_numberof_ws = math.floor(max_numberof_ws)
        # Skip the prompt and set value to 0 if there's no more quota left
        if max_numberof_ws <= 0:
            set_to_zero(f"You don't have enough quota to deploy any {machine_properties[machine]['name']}.")
            return 0

        print(f"    {chr(index)}. You can have up to {max_numberof_ws} {machine_properties[machine]['name']} workstations.")            
        while True:
            try:
                number = int(input(f"       Number of {machine_properties[machine]['name']} ({machine}): ").strip() or DEFAULT_NUMBEROF_WS)
                if (number < 0):
                    raise ValueError
                if (number <= max_numberof_ws):
                    cpe_quota_reserve(machine, number, gcp_region, gcp_zone)
                    return number
                # If there's enough quota but number of workstations requested exceeds the 
                # max_numberof_ws, then it means there aren't enough IP addresses in the subnet.
                if (requirements_are_met(machine, number, gcp_region, gcp_zone)):
                    print(f"There are only {max_numberof_ws} available IP addresses in the 10.0.2.0/24 subnet. ", end="")
            except ValueError:
                print("       Invalid number input. ", end="")
            print("Please try again.")

    def vpc_list_get():
        request = cpe_service.networks().list(project=project_id)
        while request is not None:
            response = request.execute()
            vpc_list = [item['name'] for item in response['items']]

            request = cpe_service.networks().list_next(previous_request=request, previous_response=response)
        return vpc_list

    def prefix_get(order_number):
        print(f"{order_number}.  Prefix to add to the names of resources to be created (Maximum 5 characters. Default: {DEFAULT_PREFIX}).")
        
        vpc_list = vpc_list_get()
        while True:
            prefix = input("prefix: ").strip() or DEFAULT_PREFIX
            if (len(prefix) > 5):
                print("    Prefix should have a maximum of 5 characters to avoid cropping of workstation hostnames. Please try again.")
                continue
            
            vpc_name = f'{prefix}-vpc-anyware'
            if vpc_name in vpc_list:
                print("vpc_name already exists. Please enter a different prefix.")
                continue
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
        available_cpe_quota = {} # Dictionary to keep track of available Compute engine quota
        required_cpe_quota = { m: 0 for m in METRICS } # Dictionary to keep track of required Compute engine quota
        ws_count = 0 # Variable to keep track of workstations count
        cfg_data['prefix'] = prefix_get("1")
        print("\n")

        cfg_data['reg_code'] = reg_code_get("2")
        print("\n")

        cfg_data['api_token'] = api_token_get("3")
        print("\n")

        print(f"4.  The default region is {DEFAULT_REGION} and the default zone is {DEFAULT_ZONE}.")
        customize = not answer_is_yes("    Would you like to continue with the default selections (y/n)? ")

        # GCP Region and Zone while loop
        while True:
            if customize:
                print("")
                print("    Getting GCP regions list...")
                print("") # For formatting purposes
                cfg_data['gcp_region'] = region_get("a")
            else:
                cfg_data['gcp_region'] = DEFAULT_REGION

            # Get the regional quota, print them out in a table, and check if there's 
            # enough quota to deploy one CAC and one DC instance
            available_cpe_quota = cpe_quota_get(cfg_data['gcp_region'])
            cpe_quota_print(cfg_data['gcp_region'])
            if not region_requirements_met(cfg_data['gcp_region']):
                customize = True
                continue # back to the beginning of the GCP region and zone while loop

            if customize:
                print("")
                print("    Getting GCP zones list...")
                print("")
                cfg_data['gcp_zone'] = zone_get("b", cfg_data['gcp_region'])
            else:
                cfg_data['gcp_zone'] = DEFAULT_ZONE

            # Print accelerator availability report
            print("")
            for machine in ws_types:
                requirements_are_met(machine, 0, cfg_data['gcp_region'], cfg_data['gcp_zone'], print_cpe_report=False, print_gpu_report=True)

            if answer_is_yes(f"\nWould you like to continue with region {cfg_data['gcp_region']} and zone {cfg_data['gcp_zone']} (y/n)? "):
                break # break out of the GCP region and zone while loop
            customize = True

        print("\n")
        print(f"5.  Please enter the number of remote workstations to create (Default: {DEFAULT_NUMBEROF_WS}).")
        print("    Based on your remaining quota and the number of available IP addresses in the subnet...")
        index = ord('a')
        for machine in ws_types:
            print("")
            cfg_data[machine] = numberof_ws_get(index, machine, cfg_data['gcp_region'], cfg_data['gcp_zone'])
            ws_count += cfg_data[machine]
            index += 1
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
