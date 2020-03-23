# Google Cloud Platform Deployments

## GCP Quickstart Tutorial

The quickest way to create a reference deployment on GCP is to run the Quickstart Python script in the Google Cloud Shell. The goal is to automate the creation of a [single-connector deployment](#single-connector) as much as possible by using auto-generated values for required parameters.

Click on the button below to clone this repository in your GCP Cloud Shell and launch the tutorial.

[![Open in Google Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/teradici/cloud_deployment_scripts&open_in_editor=quickstart/gcp-cloudshell-quickstart.cfg&tutorial=quickstart/tutorial.md)

## Running Terraform Scripts

### Requirements
- the user must have owner permissions to a GCP project
- a PCoIP Registration Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- an SSH private / public key pair is required for Terraform to log into Linux hosts.
- if SSL is involved, the SSL key and certificate files are needed in PEM format.
- Terraform v0.12.x must be installed. Please download Terraform from https://www.terraform.io/downloads.html

### GCP Setup
Although it is possible to create deployments in existing and currently in-use projects, it is recommended to create them in new projects to reduce chances of name collisions and interfering with operations of existing resources.

With a new GCP project:
- create a new service account with __Editor__ and __Cloud KMS CryptoKey Encrypter/Decrypter__ permissions. Create and download the credentials in JSON format. These credentials are needed by CAM to manage the deployment, such as creating workstations, monitoring workstation statuses, and providing power management features.  The credentials are also needed by the Terraform scripts to create the initial deployment.
- enable the following APIs in the GCP console or via the command ```gcloud services enable deploymentmanager.googleapis.com cloudkms.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com dns.googleapis.com```:
    - Cloud Deployment Manager V2
    - Cloud Key Management Service (KMS)
    - Cloud Resource Manager
    - Compute Engine
    - Google Cloud DNS
- (Optional) For better security, create a Google KMS Key Ring and Crypto Key to encrypt secrets. Please refer to https://cloud.google.com/kms/docs/creating-keys for instructions to create keys.

### Cloud Access Manager Setup
Login to Cloud Access Manager Admin Console at https://cam.teradici.com using a Google G Suite, Google Cloud Identity, or Microsoft business account.
1. create a new deployment and submit the credentials for the GCP service account created above.
1. create a Connector in the new deployment. A connector token will be generated to be used in terraform.tfvars.

### (Optional) Encrypting Secrets
Secrets required as input to the Terraform scripts include Active Directory passwords, PCoIP registration key and the connector token. These secrets are stored in the local files terraform.tfvars and terraform.tfstate, and will also be uploaded as part of provisioning scripts to a Google Cloud Storage bucket.

The Terraform scripts are designed to support both plaintext and KMS-encrypted secrets. Plaintext secrets requires no extra steps, but will be stored in plaintext in the above mentioned locations. It is recommended to encrypt the secrets in the terraform.tfvars file before deploying. Secrets can be encrypted manually first before being entered into terraform.tfvars, or they can be encrypted using a python script located under tools.

#### Manual Encryption
To encrypt secrets using the KMS crypto key created above, follow the instructions here: https://cloud.google.com/kms/docs/encrypt-decrypt. Base64 encode the ciphertext before copying and pasting it into terraform.tfvars. For example, execute the following command in GCP Cloud Shell:

```echo -n <secret> | gcloud kms encrypt --location <location> --keyring <keyring_name> --key <key_name> --plaintext-file - --ciphertext-file - | base64```

#### Encryption Using Python Script
Alternatively, the kms_secrets_encryption.py Python 3 script under the tools directory can be used to automate the KMS encryption process. 

First, open the terraform.tfvars file and enter all the secrets in plaintext located under the line "# <-- Start of secrets section, do not edit this line. -->", then save the file. 

Run the script by executing the following command inside the tools directory:
```./kms_secrets_encryption.py </path/to/terraform.tfvars>```

The script will replace all your plaintext secrets inside of terraform.tfvars with ciphertext. Any text files specified under the secrets section as a path will also be encrypted. 

The script can also reverse the encryption by running with the '-d' flag. See script's documentation for details (--help).

### Customizing terraform.tfvars
terraform.tfvars is the file in which a user specify variables for a deployment. In each deployment, there is a ```terraform.tfvars.sample``` file showing the required variables that a user must provide, along with other commonly used but optional variables. Uncommented lines show required variables, while commented lines show optional variables with their default or sample values. A complete list of available variables are described in the variable definition file ```vars.tf``` of the deployment.

Save ```terraform.tfvars.sample``` as ```terraform.tfvars``` in the same directory, and fill out the required and optional variables.

If secrets are KMS-encrypted, fill in the ```kms_cryptokey_id``` variable with the crypto key used to encode the secrets, then paste the base64-encoded ciphertext for the following variables:
- ```dc_admin_password```
- ```safe_mode_admin_password```
- ```ad_service_account_password```
- ```pcoip_registration_code```
- ```cac_token```

Be sure to remove any spaces in the ciphertext.

If secrets are in plaintext, make sure ```kms_cryptokey_id``` is commented out, and fill in the rest of the variables as plaintext.

### Creating the deployment
With the terraform.tfvars file customized
1. run ```terraform init``` to initialize the deployment
1. run ```terraform apply``` to display the resources that will be created by Terraform
1. answer ```yes``` to start creating the deployment
A typical deployment should take 15 to 30 minutes. When finished, the scripts will display a number of values of interest, such as the load balancer IP address. At the end of the deployment, the resources may still take a few minutes to start up completely. Connectors should register themselves with the CAM service and show up in the CAM Admin Console.

### Add Workstations in Cloud Access Manager
Go to the CAM Admin Console and add the newly created workstations using "Add existing remote workstation" in the "Remote Workstations" tab.  Note that it may take a few minutes for the workstation to show up in the "Select workstation from directory" drop-down box.

### Start PCoIP Session
Once the workstations have been added to be managed by CAM and assigned to Active Directory users, a PCoIP user can connect the PCoIP client to the public IP of the Cloud Access Connector or Load Balancer, if one is configured, to start a PCoIP session.

### Changing the deployment
Terraform is a declarative language to describe the desired state of resources. A user can modify terraform.tfvars and run ```terraform apply``` again. Terraform will try to only apply the changes needed to acheive the new state.

Note that changes involving creating or recreating Cloud Access Connectors requires a new connector token from the CAM Admin Console. Create a new connector to obtain a new token.

### Deleting the deployment
Run ```terraform destroy``` to remove all resources created by Terraform.

## Architectures
This section describes the different types of deployment scenarios supported by Terraform scripts in this repository.

### single-connector
This is the simplest deployment; it creates a VPC with 3 subnets in the same region. The subnets are
- ```subnet-dc```: for the Domain Controller
- ```subnet-cac```: for the Connector
- ```subnet-ws```: for the workstations

Firewall rules are created to allow wide-open access within the VPC, and selected ports are open to the public for operation and for debug purposes.

A Domain Controller is created with Active Directory, DNS and LDAP-S configured. 2 Domain Admins are set up in the new domain: ```Administrator``` and ```cam_admin``` (default). Domain Users are also created if a ```domain_users_list``` CSV file is specified. The Domain Controller is given a static IP (configurable).

A Cloud Access Connector is created and registers itself with the CAM service with the given Token and PCoIP Registration code.

Domain-joined workstations are optionally created, specified by the following parameters:
- ```win_gfx_instance_count```: Windows Graphics workstation,
- ```win_std_instance_count```: Windows Standard workstation,
- ```centos_gfx_instance_count```: CentOS Graphics workstation, and
- ```centos_std_instance_count```: CentOS Standard workstation.

These workstations are automatically domain-joined and have the PCoIP Agent installed.  For graphics workstations, NVidia graphics driver are also installed.

![single-connector diagram](single-connector-gcp.png)

### multi-region

#### Note: Due to recent changes in how Google Load Balancer process headers, your current Zero Client or Software Client version may need to be updated.  Please contact the maintainer (see below) for help if you have trouble connecting through the Load Balancer. A temporary workaround is to connect to the public IP of the Cloud Access Connector directly, bypassing the Load Balancer.

The difference between single-connector and multi-region deployments is that instead of creating only one Cloud Access Connector, the multi-region deployment creates Cloud Access Connectors in managed instance groups, in one or more GCP regions, behind a single GCP HTTPS Load Balancer. In this setup, a client initiates a PCoIP session with the public IP of the HTTPS Load Balancer, and the Load Balancer will select one of the Cloud Access Connectors from a region closest to the client to establish the connection. In-session PCoIP traffic goes through the selected Cloud Access Connector directly, bypassing the HTTPS Load Balancer.

The regions and number of Cloud Access Connectors for each region are specified by the ```cac_region_list``` and ```cac_instance_count_list``` variables, respectively. At least one region and one Cloud Access Connector instance must be specified.

The following diagram shows a deployment when only a single region is specified by the user.

![multi-connector diagram](single-region.png)

Specifying multiple regions creates a deployment with Cloud Access Connectors in multiple regions, but workstations in only one region. A user initiating a PCoIP session with the public IP of the GCP HTTPS Load Balancer will connect to one of the closest Cloud Access Connectors and use GCP's global network to connect to the workstation.

![multi-region diagram](multi-region.png)

### dc-only
A simple deployment of one Domain Controller, intended for testing Domain Controller operations.

Creates one VPC, one subnet and a single Domain Controller with ports opened
for ICMP, RDP and WinRM.  Domain Controller is configured with Acitve
Directory, DNS, LDAP-S.  One AD Service Account is also created.
