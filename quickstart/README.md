# Quickstart on GCP
The quickest way to create an example deployment on GCP is to use the Quickstart Python script. The goal is to automate the creation of a [single-connector deployment](../README.md#single-connector) as much as possible by using auto-generated values for required parameters.

For a more customizable deployment, please use the standard Terraform deployment scripts directly [here](../README.md).

## Requirements
- the user must have owner permissions to a GCP project
- A PCoIP Registration Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- A Cloud Access Manager API Token is needed. Follow the instructions available after clicking the button below to obtain a token.

## Steps
1. click on the button below to clone this repository in your GCP Cloud Shell. An editor should automatically open, showing gcp-cloudshell-quickstart.cfg.
1. follow the instructions in the file and fill in the required parameters
1. run ```./gcp-cloudshell-quickstart.py``` from the GCP Cloud Shell

[![Open in Cloud Shell][shell_img]][shell_link]

[shell_img]: http://gstatic.com/cloudssh/images/open-btn.png
[shell_link]: https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/teradici/cloud_deployment_scripts&page=editor&open_in_editor=quickstart/gcp-cloudshell-quickstart.cfg
