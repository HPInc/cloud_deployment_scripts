"""
checks for the latest os and updates the os versions in vars.tf file in dc-only,
multi-region and single connector deployments.
Use this command to run this script in cloud shell: python3 tools/automate_gcp_os_version.py
"""
import datetime
import os
import re
import subprocess

COMPUTE_SERVICES_ENABLE = "gcloud services enable compute.googleapis.com"
OS_COMMAND = "gcloud compute images list"
PATHS = [["single-connector", "vars.tf"],
         ["multi-region", "vars.tf"],
         ["dc-only", "vars.tf"],
         ["nlb-multi-region", "vars.tf"],
         ["cas-mgr-single-connector", "vars.tf"],
         ["cas-mgr-multi-region", "vars.tf"],
         ["cas-mgr-nlb-multi-region", "vars.tf"]]


def get_os():
    """
    get the latest version from GCP
    """
    try:
        recent_os = []
        capture_output = subprocess.run(OS_COMMAND.split(' '), check=True,
                                        capture_output=True).stdout.decode().split('\n')
        recent_os.extend([key[0] for key in map(lambda x: x.split(' '), capture_output)])
        return recent_os
    except (AttributeError, TypeError, subprocess.CalledProcessError) as ex:
        print("Exception occurred: ", ex)


def compare_versions(recent_os, line):
    """
    Checks for version numbers and returns true if latest version available
    """
    try:
        reg_obj = re.compile('([\\w-]+)-v([0-9]{8})')

        # Get the base name from OS image name.
        def get_os_name(image_name):
            match = reg_obj.search(image_name)
            if not match:
                return None
            return match.group(1)

        # Get the date from OS image name
        def get_os_date(image_name):
            match = reg_obj.search(image_name)
            if not match:
                return None
            return datetime.datetime.strptime(match.group(2), "%Y%m%d")

        os_image_name = line.split("/")[-1]
        os_name = get_os_name(os_image_name)

        if not os_name:
            return False, None

        for _os in recent_os:
            if os_name == get_os_name(_os):
                return get_os_date(os_image_name) < get_os_date(_os), _os

        return False, None
    except (AttributeError, TypeError) as ex:
        print("Exception occurred: ", ex)


def modify_file_content(file_path, recent_os):
    """
    Modifies os versions to latest versions available in the cloud
    """
    try:
        updated = False
        with open(file_path, 'r+') as original_file:
            lines = original_file.readlines()
            for index, line in enumerate(lines):
                if "global/images/" in line:
                    result = compare_versions(recent_os, line)
                    if result[0]:
                        updated = True
                        print(f"Found old os version at line {index+1}")
                        lines[index] = line.replace(line.split("/")[-1],
                                                    ''.join([result[1], '"\n']))

            original_file.seek(0)
            original_file.writelines(lines)
            if updated:
                print("OS versions updated successfully.")
            else:
                print("OS versions up-to-date, no changes required.")
    except AttributeError as ex:
        print("Exception occurred:", ex)


def main():
    """
    Actual program execution starts from this function
    """
    try:
        # Starting point of script
        dir_path = os.path.abspath(os.path.dirname(__name__))
        # enable compute.googleapis.com
        print("Enabling compute.googleapis.com service...")
        subprocess.run(COMPUTE_SERVICES_ENABLE.split(' '), check=True)
        print("Checking for latest os...")
        # getting arguments from commandline
        latest_os = get_os()
        for path in PATHS:
            current_path = os.path.join(dir_path, "deployments", "gcp", *path)
            print("Modifying os version in path: ", current_path)
            modify_file_content(current_path, latest_os)
    except (AttributeError, ValueError) as ex:
        print("Exception occurred:", ex)


if __name__ == "__main__":
    # Starting point of script
    main()
