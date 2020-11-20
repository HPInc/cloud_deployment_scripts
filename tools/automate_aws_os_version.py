#!/usr/bin/env python3

# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import datetime
import json
import os
import re
import subprocess

CMD_ARGS = [{'owner': 'amazon', 'value': '*Windows_Server-2019-English-Full-Base-*', 'os_name': 'Windows'},
            {'owner': '099720109477', 'value': '*ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*',
             'os_name': 'ubuntu'},
            {'owner': 'aws-marketplace', 'value': '*b7ee8a69-ee97-4a49-9e68-afaee216db2e*', 'os_name': 'CentOS'}]

OS_COMMANDS = [f'aws ec2 describe-images --owners {CMD_ARGS[0]["owner"]} --filters "Name=name,Values={CMD_ARGS[0]["value"]}" --query "sort_by(Images, &CreationDate)[].Name"',
               f'aws ec2 describe-images --owners {CMD_ARGS[1]["owner"]} --filters "Name=name,Values={CMD_ARGS[1]["value"]}" --query "sort_by(Images, &CreationDate)[].Name"',
               f'aws ec2 describe-images --owners {CMD_ARGS[2]["owner"]} --filters "Name=name,Values={CMD_ARGS[2]["value"]}" --query "sort_by(Images, &CreationDate)[].Description"']

PATHS = [["single-connector", "vars.tf"],
         ["lb-connectors", "vars.tf"],
         ["lb-connectors-lls", "vars.tf"],
         ["lb-connectors-ha-lls", "vars.tf"]]

latest_aws_os = []


def get_os():
    """
    get the latest version from AWS
    """
    try:
        for cmd in OS_COMMANDS:
            capture_output = subprocess.run(cmd, capture_output=True)
            if capture_output.stderr.decode():
                print(capture_output.stderr.decode())
                exit(0)
            recent_os = json.loads(capture_output.stdout.decode())
            latest_aws_os.extend(recent_os)
        return latest_aws_os
    except (AttributeError, TypeError, subprocess.CalledProcessError) as ex:
        print("Exception occurred: ", ex)


def compare_versions(latest_os, line):
    """
    Compare OS versions available in vars.tf with latest OS in AWS
    """
    result = ""
    try:
        name_exp = re.compile(r"([a-zA-Z]+)")
        date_exp = re.compile(r"([0-9.])")

        def get_os_name(image_name):
            match = name_exp.search(image_name)
            return match.group(1)

        def get_os_date(image_name):
            match2 = date_exp.findall(image_name)
            listtostr = ' '.join(map(str, match2))
            os_dates = listtostr.replace(" ", "").split("/")
            for os_date in os_dates:
                if os_name == CMD_ARGS[0]["os_name"]:
                    return datetime.datetime.strptime(os_date[4:14], "%Y.%m.%d")
                if os_name == CMD_ARGS[1]["os_name"]:
                    return datetime.datetime.strptime(os_date[7:15], "%Y%m%d")
                if os_name == CMD_ARGS[2]["os_name"]:
                    return datetime.datetime.strptime(os_date[5:9], "%y%m")
            return match2
        os_image_name = line.split("=")[-1]
        os_name = get_os_name(os_image_name)
        if not os_name:
            return False, None

        for _os in latest_os:
            if os_name == get_os_name(_os):
                if get_os_date(os_image_name) < get_os_date(_os):
                    result = _os
                else:
                    result = ""
        return result
    except (AttributeError, TypeError) as ex:
        print("Exception occurred: ", ex)


def modify_file_content(file_path, latest_os):
    """
    Modifies os versions to latest versions available in the cloud
    """
    try:
        updated = False
        with open(file_path, 'r+') as original_file:
            lines = original_file.readlines()
            result = ""
            for index, line in enumerate(lines):
                if "Windows_Server" in line:
                    result = compare_versions(latest_os, line)
                if "ubuntu/images" in line:
                    result = compare_versions(latest_os, line)
                if "CentOS Linux 7 x86_64 HVM" in line:
                    result = compare_versions(latest_os, line)
                if len(result)>0:
                    updated = True
                    print(f"Found old os version at line {index + 1}")
                    lines[index] = line.replace(line.split("=")[-1], ''.join([' '+'"%s"' % result, '\n']))
                    result = ""

            original_file.seek(0)
            original_file.writelines(lines)
            if updated:
                print("OS versions updated successfully.")
            else:
                print("OS versions up-to-date, no changes required.")
    except AttributeError as ex:
        print("Exception occurred: ", ex)


def main():
    """
    This function helps to call various functions and these will
        1) checks for latest OS images
        2) read vars.tf file in AWS deployments
        3) Updates OS image names in vars.tf with latest OS
    """
    try:
        dir_path = os.path.dirname(os.path.abspath(os.path.dirname(__name__)))
        print("Checking for latest os...")
        # getting arguments from commandline
        latest_os = get_os()
        for path in PATHS:
            current_path = os.path.join(dir_path, "deployments", "aws", *path)
            print("Modifying os version in path: ", current_path)
            modify_file_content(current_path, latest_os)
    except (AttributeError, ValueError) as ex:
        print("Exception occurred: ", ex)


if __name__ == "__main__":
    main()
