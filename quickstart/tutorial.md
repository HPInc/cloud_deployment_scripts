# Cloud Access Connector Quickstart

## Introduction
The goal of this tutorial is to create the [single-connector](https://github.com/teradici/cloud_deployment_scripts#single-connector) deployment in as few steps as possible by using Python and Terraform scripts.

This tutorial will guide you in entering a few parameters in a configuration file before showing you how to run a Python script in the Cloud Shell to create the Cloud Access Connector deployment.

The Python script is a wrapper script that sets up the environment required for running Terraform scripts, which actually creates the GCP infrasturcture such as Networking and Compute resources.

**Time to complete**: about 30 minutes

## Enter Parameters
Click
<walkthrough-editor-open-file
    filePath="cloud_deployment_scripts/quickstart/gcp-cloudshell-quickstart.cfg">
    here
</walkthrough-editor-open-file>
to open the configuration file in the GCP Cloud Shell Editor. Fill in the following values:

### reg_code
Replace **`<code>`** with your PCoIP Registration code.

If you don't have one, visit [https://www.teradici.com/compare-plans](https://www.teradici.com/compare-plans)

### api_token
Replace **`<token>`** with the Cloud Access Manager API token.

Log into [https://cam.teradici.com/beta-ui](https://cam.teradici.com/beta-ui) using your G Suite or Cloud Identity account, click on your email address on the top right, and select **Get API token**.

### Number of Workstations
Enter the number of workstations to create.

Parameter | Description
--- | ---
scent | Standard CentOS 7 Workstations
gcent | CentOS 7 with NVIDIA Tesla P4 Virtual Workstations GPU
gwin | Windows Server 2016 with NVIDIA Tesla P4 Virtual Workstations GPU

### Check your Quota
Please ensure there is sufficient CPU, SSD, GPU, etc. quota in your project for the chosen number of workstations, on top of the Domain Controller (DC) and Cloud Access Connector (CAC) which will also be created.

The deployment will be created in **us-west2-b** and have the following specs:

VM | vCPUs | Memory (GB) | SSD (GB) | GPU 
---|---|---|---|--- 
DC | 4 | 15 | 50 | 0
CAC | 2 | 7.5 | 50 | 0 
scent | 2 | 7.5 | 50 | 0 
gcent | 2 | 7.5 | 50 | 1
gwin | 4 | 15 | 50 | 1

You can check your quota [here](https://console.cloud.google.com/iam-admin/quotas).

### Save the changes
To save the configuration file, open the
<walkthrough-editor-spotlight spotlightId="fileMenu"
                              text="file menu">
</walkthrough-editor-spotlight> and choose **Save**.

## Create Deployment
### Select the project
Ensure the proper project is selected. Replace **<project_id>** with your project ID in the command below.
```bash
gcloud config set project <project_id>
```

### Run the script

Run the following command in Cloud Shell. You will be prompted to create a password for the Active Directory Administrator.

```bash
cd quickstart
./gcp-cloudshell-quickstart.py
```

The script should take approximately 25 minutes to run.

## Next steps

### Connect to a workstation

1. from a PCoIP client, connect to the public IP Address of the Cloud Access Connector
2. sign in with the **Administrator** user credentials

**Note:** When connecting to a workstation immediately after this script completes, the workstation (especially graphics ones) may still be setting up. You may see "Remote Desktop is restarting..." in the client. Please wait a few minutes or reconnect if it times out.

### Add additional workstations
1. Log in to [https://cam.teradici.com/beta-ui](https://cam.teradici.com/beta-ui)
2. Click on **Remote Workstations** in the left panel, select **Create Remote workstation** from the **+** button
3. Select connector **`sample_connector_<timestamp>`**
4. Fill in the form according to you preferences. Note that the following
   values must be used for their respective fields:
```
Region:                   "us-west2"
Zone:                     "us-west2-b"
Network:                  "vpc-cas"
Subnetowrk:               "subnet-ws"
Domain name:              "example.com"
Domain service account:   "cam_admin"
Service account password: <set by you at start of script>
```
5. Click **Create**

### Clean up
  1. Using GCP console, delete all workstations created by Cloud Access Manager
     web interface and manually created workstations. Resources not created by
     the Terraform scripts must be manually removed before Terraform can
     properly destroy resources it created.
  2. In GCP cloudshell, go to the **~/cloud_deployment_scripts/quickstart/** directory
     and run 
```bash
terraform destroy
```
  3. Log in to [https://cam.teradici.com/beta-ui](https://cam.teradici.com/beta-ui) and delete the deployment named
     **`sample_deployment_<timestamp>`**
