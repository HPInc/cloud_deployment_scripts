import datetime
import os
import json
import re
import subprocess
OS_COMMANDS = ['aws ec2 describe-images --owners amazon --filters "Name=name,Values=*Windows_Server-2019-English-Full-Base-*" --query "sort_by(Images, &CreationDate)[].Name"',
               'aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=*ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*" --query "sort_by(Images, &CreationDate)[].Name"',
               'aws ec2 describe-images --owners aws-marketplace --filters "Name=name,Values=*b7ee8a69-ee97-4a49-9e68-afaee216db2e*" --query "sort_by(Images, &CreationDate)[].Description"']
PATHS = [["single-connector", "vars.tf"],
         ["lb-connectors", "vars.tf"]]


latest_aws_os = []

def get_os():
    """
        get the latest version from AWS
        """
    try:
        for os in OS_COMMANDS:
            capture_output=subprocess.run(os,capture_output=True).stdout.decode()
            recent_os=json.loads(capture_output)
            latest_aws_os.extend([key for key in map(lambda x: x, recent_os)])
        return latest_aws_os
    except (AttributeError, TypeError, subprocess.CalledProcessError) as ex:
        print("Exception occurred: ", ex)



def compare_versions(latest_os,line):
    emp=""
    try:
        reg=re.compile(r"([a-zA-Z]+)")
        reg1=re.compile(r"([0-9.])")

        def get_os_name(image_name):
            match = reg.search(image_name)
            return match.group(1)

        def get_os_date(image_name):
            match2=reg1.findall(image_name)
            listtostr = ' '.join(map(str, match2))
            os_dates=listtostr.replace(" ","").split("/")
            for os_date in os_dates:
                if os_name == "Windows":
                    return datetime.datetime.strptime(os_date[4:14], "%Y.%m.%d")
                if os_name == "ubuntu":
                    return datetime.datetime.strptime(os_date[7:15], "%Y%m%d")
                if os_name == "CentOS":
                    return datetime.datetime.strptime(os_date[5:9], "%y%m")
            return match2
        os_image_name = line.split("=")[-1]
        os_name = get_os_name(os_image_name)
        if not os_name:
            return False, None

        for _os in latest_os:
            if os_name == get_os_name(_os):
                if get_os_date(os_image_name) < get_os_date(_os):
                    emp=_os
                else:
                    emp=""
        return emp
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
            result= ""
            for index, line in enumerate(lines):
                if "Windows_Server" in line:
                    result=compare_versions(latest_os, line)
                if "ubuntu/images" in line:
                    result = compare_versions(latest_os, line)
                if "CentOS Linux 7 x86_64 HVM" in line:
                    result = compare_versions(latest_os, line)
                if len(result)>0:
                    updated = True
                    print(f"Found old os version at line {index + 1}")
                    lines[index]=line.replace(line.split("=")[-1], ''.join([' '+'"%s"'%result, '\n']))
                    result=""

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
        dir_path = os.path.dirname(os.path.abspath(os.path.dirname(__name__)))
        print("Checking for latest os...")
        # getting arguments from commandline
        latest_os = get_os()
        for path in PATHS:
            current_path = os.path.join(dir_path, "deployments", "aws", *path)
            print("Modifying os version in path: ", current_path)
            modify_file_content(current_path, latest_os)
    except (AttributeError, ValueError) as ex:
        print("Exception occurred:", ex)


if __name__ == "__main__":
    # Starting point of script
    main()