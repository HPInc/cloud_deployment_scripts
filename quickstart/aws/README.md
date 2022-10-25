# Cloud Access Connector Quickstart

## Table of Contents
- [Cloud Access Connector Quickstart](#cloud-access-connector-quickstart)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Requirements](#requirements)
    - [Accessing the Quickstart Script](#accessing-the-quickstart-script)
    - [AWS Setup](#aws-setup)
    - [Enter Parameters](#enter-parameters)
      - [reg_code](#reg_code)
      - [api_token](#api_token)
      - [aws_region](#aws_region)
      - [Number of Workstations](#number-of-workstations)
      - [Prefix](#prefix)
    - [Creating the Deployment](#creating-the-deployment)
  - [Next Steps](#next-steps)
    - [Connecting to the Workstations](#connecting-to-the-workstations)
    - [Deleting the Deployment](#deleting-the-deployment)

---

## Getting Started
The Quickstart deployment allows the user to deploy a [single-connector](https://github.com/teradici/cloud_deployment_scripts/blob/master/docs/aws/README.md#single-connector) deployment in as few steps as possible by using Python and Terraform scripts. The Python script is a wrapper script that sets up the environment required for running Terraform scripts, which actually creates the AWS infrastructure such as Networking and Compute resources.

You can run the deployment from your local machine or from AWS CloudShell. This link wll take you to the **us-west-2** cloudshell, but you can choose any other available region: https://us-west-2.console.aws.amazon.com/cloudshell/home?region=us-west-2. If you are running from AWS CloudShell, you don't need to install the AWS CLI.

### Requirements
- the user must have Administrator permissions in an AWS account
- a PCoIP Registration Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- the user must have Git installed. Please see: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
- if the user is running from their local machine, they must have AWS CLI Version 2 installed. Please see: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html

### Accessing the AWS Quickstart Script
Run the following commands to clone the Cloud Deployment Scripts repository.
```bash
git clone https://github.com/teradici/cloud_deployment_scripts.git
```

### AWS Setup
Although it is possible to create deployments in existing and currently in-use accounts, it is recommended to create them in new accounts to reduce chances of name collisions and interfering with operations of existing resources.

With a new AWS account:
- from the AWS console, create a new IAM user with programmatic access and apply the __AdministratorAccess__ policy either by adding the user to a group with such permission, or by attaching the policy to the user directly. 
- run `aws configure` and set the Access key ID and Secret access key with the newly created credentials. Please see https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.

### Enter Parameters
Run the following command to navigate to the AWS quickstart directory and run the script
```bash
cd cloud_deployment_scripts/quickstart/aws/
./aws-quickstart.py
```
and you will be prompted to enter each parameter. You will also be prompted to create a password for the Active Directory Administrator. After you answer all the prompts, the script will continue to create the deployment and should take approximately 25 minutes to run.

#### reg_code
Enter your PCoIP Registration code.

If you don't have one, visit [https://www.teradici.com/compare-plans](https://www.teradici.com/compare-plans)

### api_token
Enter the Anyware Manager API token.

Log into [https://cas.teradici.com](https://cas.teradici.com) using your Google Workspace or Cloud Identity account, click on your email address on the top right, and select **Get API token**.

#### aws_region
Enter the AWS Region you want to deploy in.

#### Number of Workstations
Enter the number of workstations to create.

Parameter | Description
--- | ---
scent | Standard CentOS 7 Workstation
gcent | CentOS 7 with NVIDIA T4 G4dn Virtual Workstation GPU
swin | Windows Server 2019 Workstation
gwin | Windows Server 2019 with NVIDIA T4 G4dn Virtual Workstation GPU

#### Prefix
Enter a unique prefix to make sure there are no existing AWS resources in the account with the same name, because an error will occur if that happens. The prefix can be anything within 5 characters long.

## Next Steps
### Connecting to the Workstations

1. From a PCoIP client, connect to the public IP Address of the Cloud Access Connector. To install a PCoIP client, please see: https://docs.teradici.com/find/product/software-and-mobile-clients
2. Sign in with the **Administrator** user credentials

**Note:** When connecting to a workstation immediately after this script completes, the workstation (especially graphics ones) may still be setting up. You may see "Remote Desktop is restarting..." in the client. Please wait a few minutes or reconnect if it times out.

### Deleting the Deployment

  1. Make sure you are at the directory **/cloud_deployment_scripts/deployments/aws/single-connector**
  2. Remove resources deployed by Terraform using the following command. Enter "yes" when prompted to confirm.
```bash
terraform destroy
```
**Note:** If you had answered "yes" when prompted to allow the script to install Terraform, to make sure you are using the correct Terraform version, please execute the following command instead.
```bash
~/bin/terraform destroy
```

  3. Log in to [https://cas.teradici.com](https://cas.teradici.com) and delete the deployment named
     **`quickstart_deployment_<timestamp>`**

### Deleting the AWS IAM Resources

1.  The script created an IAM policy, role, access key, and user to allow Terraform to create and Anyware Manager to manage AWS resources. Before removing these IAM resources, you must first make sure to complete **all** previous steps to delete the deployment. 
2.  Then, run the following commands:
```bash
aws iam detach-role-policy --role-name <prefix>-anyware-manager_role --policy-arn arn:aws:iam::<account-id>:policy/<prefix>-anyware-manager_role_policy
aws iam delete-policy --policy-arn arn:aws:iam::<account-id>:policy/<prefix>-anyware-manager_role_policy
aws iam delete-role --role-name <prefix>-anyware-manager_role
aws iam delete-access-key --user-name <prefix>-anyware-manager --access-key-id <access-key-id>
aws iam detach-user-policy --user-name <prefix>-anyware-manager --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-user --user-name <prefix>-anyware-manager
```

