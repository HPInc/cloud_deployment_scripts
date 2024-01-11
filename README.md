# HP Anyware

Hp Anyware delivers a highly responsive remote desktop experience with color-accurate, lossless and distortion-free graphics – even for high frame rate 4K/UHD graphics workloads. This is exactly why artists, editors, producers, architects, and designers all trust HP Anyware to provide the resolution, sound, and color fidelity they need to create and work from anywhere. The immersive, feature-rich experience that HP Anyware delivers is the reason why we won an Engineering Emmy in 2020.

Based on our secure PCoIP® (PC-over-IP) protocol that connects over 15 million endpoints around the globe, HP Anyware makes all the magic happen for Windows, Linux and macOS (coming soon) desktops and applications through three core software components:

- **PCoIP Agents** in any standalone or virtualized workstation, on-prem data center, cloud, multicloud or hybrid host environment
- **Anyware Manager** to secure, broker, and provision HP Anyware connections
- **PCoIP Clients** to enable any PCoIP Zero Client, PCoIP-Enabled Thin Client, PC, Mac, laptop, or tablet to access their remote desktops, fixed or mobile workstations from anywhere

For more details, please visit https://teradici.com.

This repository contains a collection of Terraform configurations for demonstrating how to deploy Anyware Manager and Anyware Connectors in a user's cloud environment. __Note: These configurations are suitable for creating reference deployments for demonstration, evaluation, or development purposes. The infrastructure created may not meet the reliability, availability, or security requirements of your organization.__

# Documentation
- [Instructions](docs/aws/README.md) for deploying HP Anyware on Amazon Web Services
- [Instructions](docs/gcp/README.md) for deploying HP Anyware on Google Cloud Platform

HP Anyware deployments on Microsoft Azure is available in a separate repository. Please visit https://github.com/HPInc/Azure_Deployments

# Directory structure
## deployments/
The top level Terraform configuration that creates entire deployments.

## docs/
Description and instructions for deployments on different clouds.

## modules/
The building blocks of deployments, e.g. a Domain Controller, a Anyware Connector, a Workstation, etc.

## provisioning-scripts/
Contains provisioning scripts to run when creating an individual virtual machine to configure the instance for PCoIP access. These scripts are similar to the scripts used to set up remote workstations under the modules/ directory, except certain features are removed, such as KMS decryption and domain joining. These scripts are meant to be used as the "User data" script in AWS or "Startup script" in GCP when creating a new instance.

## quickstart/
Contains Quickstart scripts, which are Python scripts for quick deployment of the single-connector deployment on GCP or AWS. The Python scripts take care of preparing for some of the requirements such as creating SSH keys, creating service accounts and enabling cloud services.

## tools/
Various scripts to help with Terraform deployments.  e.g. a Python script to generate random users for an Active Directory in a CSV file.

# Maintainer
If any security issues or bugs are found, or if there are feature requests, please contact the HP Anyware Cloud Solutions & Services team at anyware.cloud.deployment.scripts@hp.com
