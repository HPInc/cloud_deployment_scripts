# Amazon Web Services Deployments

## Table of Contents
- [Amazon Web Services Deployments](#amazon-web-services-deployments)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [AWS Quickstart](#aws-quickstart)
  - [Manual Terraform Configuration](#manual-terraform-configuration)
    - [Requirements](#requirements)
    - [Selecting a Deployment](#selecting-a-deployment)
    - [AWS Setup](#aws-setup)
    - [CAS Manager as a Service Setup](#cas-manager-as-a-service-setup)
    - [Customizing terraform.tfvars](#customizing-terraformtfvars)
    - [(Optional) Encrypting Secrets](#optional-encrypting-secrets)
      - [Encryption Using Python Script](#encryption-using-python-script)
      - [Manual Encryption](#manual-encryption)
    - [Creating the deployment](#creating-the-deployment)
    - [Add Workstations in CAS Manager](#add-workstations-in-cas-manager)
    - [Start PCoIP Session](#start-pcoip-session)
    - [Changing the deployment](#changing-the-deployment)
    - [Deleting the deployment](#deleting-the-deployment)
  - [Troubleshooting](#troubleshooting)

---

## Introduction

There are two ways to create a Cloud Access Software (CAS) deployment using this repository:
- [__AWS Quickstart__](#aws-quickstart): for those who have less experience with the CLI and Terraform, use this to get a deployment running with the least amount of effort. The quickstart will prepare most of the requirements for the user and call a script to deploy the _single-connector_ deployment using Terraform.
- [__Manual Terraform Configuration__](#manual-terraform-configuration): for those who are experienced with the CLI and Terraform, this is the primary way this repository is meant to be used. A user can choose between different types of deployments, variables can be customized, and deployment architecture can be modified to suit the user's needs.

## AWS Quickstart

The quickest way to create a reference deployment on AWS is to run the Quickstart Python script in the AWS CloudShell or your local CLI. The goal is to automate the creation of a [single-connector deployment](#single-connector) as much as possible by using auto-generated values for required parameters.

To go to the AWS Quickstart directory, click [here](/quickstart/aws/)

## Manual Terraform Configuration

Before starting, consider watching [this video](https://www.youtube.com/watch?v=hwEOoG4pmMQ) on how to use this repo to deploy a single-connector deployment on AWS from a Windows environment. The video guides the viewer through the entire deployment process from set up to tear down. It also shows how the deployment can be managed through CAS Manager as a Service (CAS-MS) and how end-users can connect to their machines using a PCoIP client. While the video shows the single-connector deployment, the process of creating other deployments is very similar. For deployment from a Linux environment, please see the relevant portions of our [GCP video](https://www.youtube.com/watch?v=ESzon04cW4Y). Note that since this repository is constantly being updated, there might be minor differences between what is shown in the video compared to the latest version on GitHub.

### Requirements
- the user must have Administrator permissions in an AWS account
- a PCoIP Registration Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- a PCoIP Registration Code and/or PCoIP License Server Activation Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- for CAS deployments using PCoIP License Server, an activation code with PCoIP session licenses is needed.
- for deployments using CAS Manager as a Service, a CAS Manager Deployment Service Account is needed. Please see the [CAS Manager as a Service Setup])#cas-manager-as-a-service-setup) section below.
- an SSH private / public key pair is required for Terraform to log into Linux hosts. Please visit [ssh-key-pair-setup.md](/docs/ssh-key-pair-setup.md) for instructions.
- if custom SSL key and certificates are required, the SSL key and certificate files are needed in PEM format.
- Terraform v1.0 or higher must be installed. Please download Terraform from https://www.terraform.io/downloads.html

### Selecting a Deployment
This repository contains Terraform configurations for a number of different CAS deployment types. Please see the the [Deployments](deployments.md) page for a more detailed description of the various deployments.

### AWS Setup
Although it is possible to create deployments in existing and currently in-use accounts, it is recommended to create them in new accounts to reduce chances of name collisions and interfering with operations of existing resources.

With a new AWS account:
- from the AWS console, create a new IAM user with programmatic access and apply the __AdministratorAccess__ policy either by adding the user to a group with such permission, or by attaching the policy to the user directly. Copy the Access key ID and Secret access key into an AWS Credential File as shown below. These credentials are needed by the Terraform configurations to create the initial deployment. Please see https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html for more details on AWS Credential Files.
```
[default]
aws_access_key_id = <your_id>
aws_secret_access_key = <your_key>
```
- (Optional) For better security, create an AWS KMS Customer Managed Symmetric Customer Master Key (CMK) to encrypt secrets.  Please refer to https://docs.aws.amazon.com/kms/latest/developerguide/create-keys.html for instructions to create CMKs.

### CAS Manager as a Service Setup
(for deployments using the CAS Manager as a Service only)

Follow the steps below to set up a CAS Manager deployment and download CAS Manager Deployment Service Acccount credentials. For deployments using CAS Manager running in a virtual machine, these steps can be skipped because the Terraform configuration will automatically set those up for the user.

1. Login to CAS Manager Admin Console at https://cas.teradici.com using a Google Workspace, Google Cloud Identity, or Microsoft business account.
2. Create a new deployment with your PCoIP registration code.
4. Select `Edit deployment`, select the `CLOUD SERVICE ACCOUNTS` tab, and follow the instructions to add your AWS account.
5. Select `Edit deployment`, select the `DEPLOYMENT SERVICE ACCOUNTS` tab, click on the + icon to create a CAS Manager Deployment Service Account.
6. Click on `DOWNLOAD JSON FILE` to download the CAS Manager Deployment Service Account credentials file, which will be used in `terraform.tfvars`.

### Customizing terraform.tfvars
`terraform.tfvars` is the file in which a user specify variables for a deployment. In each deployment, there is a `terraform.tfvars.sample` file showing the required variables that a user must provide, along with other commonly used but optional variables. Uncommented lines show required variables, while commented lines (those beginning with `#`) show optional variables with their default or sample values. A complete list of available variables are described in the variable definition file `vars.tf` of the deployment.

Path variables in `terraform.tfvars` must be absolute and are dependent on the host platform:
- On Linux systems, the forward slash / is used as the path segment separator. `aws_credentials_file = "/path/to/aws_key"`
- On Windows systems, the default Windows backslash \ separator must be changed to forward slash as the path segment separator. `aws_credentials_file = "C:/path/to/aws_key"`

Save `terraform.tfvars.sample` as `terraform.tfvars` in the same directory, and fill out the required and optional variables.

### (Optional) Encrypting Secrets
`terraform.tfvars` variables include sensitive information such as Active Directory passwords, PCoIP registration key and the CAS Manager Deployment Service Account credentials file. These secrets are stored in the local files `terraform.tfvars` and `terraform.tfstate`, and will also be uploaded as part of provisioning scripts to an AWS S3 bucket.

To enhance security, the Terraform configurations are designed to support both plaintext and KMS-encrypted secrets. Plaintext secrets requires no extra steps, but will be stored in plaintext in the above mentioned locations. It is recommended to encrypt the secrets in `terraform.tfvars` before deploying. Secrets can be encrypted manually first before being entered into `terraform.tfvars`, or they can be encrypted using a Python script located under the tools directory.

#### Encryption Using Python Script
The easiest way to encrypt secrets is to use the kms_secrets_encryption.py Python script under the tools/ directory, which automates the KMS encryption process.
1. First, fill in all the variables in `terraform.tfvars`, including any sensitive information.
2. Ensure the `customer_master_key_id` variable in `terraform.tfvars` is commented out, as this script will attempt to create the crypto key used to encrypt the secrets:
   ```
   # customer_master_key_id = "<key-id-uuid>"
   ```
3. Run the following command inside the tools directory:
   ```
   ./kms_secrets_encryption.py </path/to/terraform.tfvars>
   ```

The script will replace all plaintext secrets inside of `terraform.tfvars` with ciphertext. Any text files specified under the secrets section as a path will also be encrypted. 

The script can also reverse the encryption by executing it with the '-d' flag. See script's documentation for details (--help).

#### Manual Encryption
Alternatively, the secrets can be manully encrypted. To encrypt secrets using the KMS CMK created in the 'AWS Setup' section above, refer to https://docs.aws.amazon.com/cli/latest/reference/kms/encrypt.html. Note that ciphertext must be base64 encoded before being used in `terraform.tfvars`.

1. Create a KMS CMK. Please refer to https://docs.aws.amazon.com/kms/latest/developerguide/create-keys.html for instructions to create keys.
2. In `terraform.tfvars`, ensure that the `customer_master_key_id` variable is uncommented and is set to the resource path of the KMS key used to encrypt the secrets:
   ```
   customer_master_key_id = "<key-id-uuid>"
   ```
3. Run the following command in a Linux shell with aws installed to encrypt a plaintext secret:
   ```
   aws kms encrypt --key-id <cmk-id> --plaintext <secret> --output text --query CiphertextBlob
   ```
   Encrypt and replace the values of the following variables in `terraform.tfvars` with the ciphertext generated. `<ciphertext`> should be replaced with the actual ciphertext generated - do not include < and >.
   ```
   dc_admin_password           = "<ciphertext>"
   safe_mode_admin_password    = "<ciphertext>"
   ad_service_account_password = "<ciphertext>"
   pcoip_registration_code     = "<ciphertext>"
   ```
4. Run the following command in a Linux shell with aws installed to encrypt the CAS Manager Deployment Service Account JSON credentials file:
   ```
    aws kms encrypt \
        --key-id <key-id-uuid> \
        --plaintext fileb://</path/to/cas-manager-service-account.json> \
        --output text \
        --query CiphertextBlob | base64 -d > </path/to/cas-manager-service-account.json.encrypted>
   ```
    Replace the value of the `cas_mgr_deployment_sa_file` variable in `terraform.tfvars` with the absolute path to the encrypted file generated.
   ```
   cas_mgr_deployment_sa_file = "/path/to/cas-manager-service-account.json.encrypted"
   ```

The following command can be used to decrypt the ciphertext:
   ```
   aws kms decrypt --ciphertext-blob fileb://<(echo "<ciphertext>" | base64 -d) --output text --query Plaintext | base64 -d
   ```

The following command can be used to decrypt the encrypted CAS Manager Deployment Service Account JSON credentials file:
   ```
   aws kms decrypt --ciphertext-blob fileb://</path/to/cas-manager-service-account.json.encrypted> --output text --query Plaintext | base64 -d > </path/to/cas-manager-service-account.json>
   ```

### Creating the deployment
With `terraform.tfvars` customized

1. run `terraform init` to initialize the deployment
2. run `terraform apply` to display the resources that will be created by Terraform
3. answer `yes` to start creating the deployment

A typical deployment should take 15 to 30 minutes. When finished, Terraform will display a number of values of interest, such as the load balancer IP address. At the end of the deployment, the resources may still take a few minutes to start up completely. Cloud Access Connectors (CACs) should register themselves with CAS Manager and show up in the Admin Console in CAS Manager.

**Security Note**: The Domain Controller has been assigned a public IP address by default, so that Terraform can show the progress of setting up the Domain Controller. Access to this public IP address is limited by AWS security groups to the IP address of the Terraform host and any IP addresses specified in the `allowed_admin_cidrs` variable in `terraform.tfvars`. It is recommended that access to the Domain Controller is reviewed and modified to align with the security policies of the user.     

**Note**: If Terraform returns the error "An argument named `sensitive` is not expected here." this means that the Terraform version installed does not meet the requirements. Please see [here](#requirements) and make sure you have fulfilled all the requirements.

### Add Workstations in CAS Manager
Go to the CAS Manager Admin Console and add the newly created workstations using "Add existing remote workstation" in the "Remote Workstations" tab.  Note that it may take a few minutes for the workstation to show up in the "Select workstation from directory" drop-down box.

### Start PCoIP Session
Once the workstations have been added to be managed by CAS Manager and assigned to Active Directory users, a PCoIP user can connect the PCoIP client to the public IP of the Cloud Access Connector or Load Balancer, if one is configured, to start a PCoIP session.

### Changing the deployment
Terraform is a declarative language to describe the desired state of resources. A user can modify `terraform.tfvars` and run `terraform apply` again, and Terraform will try to only apply the changes needed to acheive the new state.

### Deleting the deployment
Run `terraform destroy` to remove all resources created by Terraform.

**Note for deployments using the PCoIP License Server (all deployments with names ending in "lls")**
Be sure to SSH into the PCoIP License Server (LLS), possibly using a Cloud Access Connector as a jumphost, and run `pcoip-return-online-license -a <activation-code>` before destroying the deployment. Otherwise, the activated PCoIP licenses will be lost.

For more information on the LLS, please visit https://www.teradici.com/web-help/pcoip_license_server/current/online/

## Troubleshooting
Please visit the [Troubleshooting](/docs/troubleshooting.md) page for further instructions.
