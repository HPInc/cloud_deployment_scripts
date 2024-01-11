# HP Anyware Connector Quickstart

## Introduction
The goal of this tutorial is to create the [single-connector](https://github.com/HPInc/cloud_deployment_scripts/blob/master/docs/gcp/deployments.md#single-connector) deployment in as few steps as possible by using Python and Terraform scripts.

This tutorial will guide you in entering a few parameters in a configuration file before showing you how to run a Python script in the Cloud Shell to create the HP Anyware Connector deployment.

The Python script is a wrapper script that sets up the environment required for running Terraform scripts, which actually creates the GCP infrastructure such as Networking and Compute resources.

**Time to complete**: about 30 minutes

## Create Deployment
### Select the Project
Ensure the proper project is selected. Replace **<project_id>** with your project ID in the command below.
```bash
gcloud config set project <project_id>
```

### Enter Parameters

Run the following command in Cloud Shell
```bash
cd quickstart/gcp
./gcp-cloudshell-quickstart.py
```
and you will be prompted to enter each parameter. After you answer all the prompts, the script will continue to create the deployment.

#### prefix
Enter a prefix for your resource names (Maximum 5 characters. Default: quick)

#### reg_code
Enter your PCoIP Registration code.

If you don't have one, visit [https://www.teradici.com/solutions/subscriptions](https://www.teradici.com/solutions/subscriptions)

#### api_token
Enter the Anyware Manager API token.

Log into [https://cas.teradici.com](https://cas.teradici.com) using your G Suite or Cloud Identity account, click on your email address on the top right, and select **Get API token**.

#### gcp_region
Enter the GCP Region you want to deploy in.     

You can see the list of GCP regions and zones [here](https://cloud.google.com/compute/docs/regions-zones)

#### gcp_zone
Enter the GCP Zone you want to deploy in.

#### Number of Workstations
Enter the number of workstations to create.

Parameter | Description
--- | ---
scent | Standard CentOS 7 Workstation
gcent | CentOS 7 with NVIDIA Tesla P4 Virtual Workstation GPU
swin | Windows Server 2019 Workstation
gwin | Windows Server 2019 with NVIDIA Tesla P4 Virtual Workstation GPU

#### Check your Quota
Please ensure there is sufficient CPU, SSD, GPU, etc. quota in your project for the chosen number of workstations, on top of the Domain Controller (DC) and Anyware Connector (AWC) which will also be created.

The deployment will have the following specs:

VM | vCPUs | Memory (GB) | SSD (GB) | GPU 
---|---|---|---|--- 
DC | 4 | 15 | 50 | 0
AWC | 2 | 7.5 | 50 | 0
scent | 2 | 7.5 | 50 | 0 
gcent | 2 | 7.5 | 50 | 1
swin | 4 | 15 | 50 | 0
gwin | 4 | 15 | 50 | 1

You can check your quota [here](https://console.cloud.google.com/iam-admin/quotas).     

You can check the availability of the GPU Virtual Workstation for the graphics machine [here](https://cloud.google.com/compute/docs/gpus/gpu-regions-zones).

## Next steps

### Connect to a workstation

1. from a PCoIP client, connect to the public IP Address of the HP Anyware Connector
2. sign in with the **Administrator** user credentials

**Note:** When connecting to a workstation immediately after this script completes, the workstation (especially graphics ones) may still be setting up. You may see "Remote Desktop is restarting..." in the client. Please wait a few minutes or reconnect if it times out.

### Add additional workstations
1. Log in to [https://cas.teradici.com](https://cas.teradici.com)
2. Click on **Workstations** in the left panel, select **Create new remote workstation** from the **+** button
3. Select connector **`quickstart_connector_<timestamp>`**
4. Fill in the form according to your preferences. Note that the following
   values must be used for their respective fields:
```
Region:                   "<set by you at start of script>"
Zone:                     "<set by you at start of script>"
Network:                  "vpc-anyware"
Subnetwork:               "subnet-ws"
Domain name:              "example.com"
Domain service account:   "anyware_ad_admin"
Service account password: <set by you at start of script>
```
5. Click **Create**

### Clean up
  1. Using GCP console, delete all workstations created by Anyware Manager
     web interface and manually created workstations. Resources not created by
     the Terraform scripts must be manually removed before Terraform can
     properly destroy resources it created.
  2. In GCP cloudshell, change directory to **~/cloudshell_open/cloud_deployment_scripts/deployments/gcp/single-connector** using the command
```bash
cd ../../deployments/gcp/single-connector
```   
  3. Remove resources deployed by Terraform using the following command. Enter "yes" when prompted to confirm.
```bash
terraform destroy
```
  Note: If Terraform was installed using this quickstart script, execute the following command instead.
```bash
~/bin/terraform destroy
```

  4. Log in to [https://cas.teradici.com](https://cas.teradici.com) and delete the deployment named
     **`quickstart_deployment_<timestamp>`**
