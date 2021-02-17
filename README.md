# Cloud Access Connector Deployment

Cloud Access Manager (CAM) enables highly-scalable and cost-effective Cloud Access Software deployments by managing cloud compute costs and brokering PCoIP connections to remote Windows or Linux workstations. The Cloud Access Manager solution is comprised of two main components – the Cloud Access Manager service, which is a service offered by Teradici to manage Cloud Access Manager deployments, and the Cloud Access Connector, which is the portion of the Cloud Access Manager solution that resides in the customer environment.  To learn more about Cloud Access Manager, visit https://www.teradici.com/web-help/pcoip_cloud_access_manager/CACv2/

This repository contains a collection of Terraform scripts for demonstrating how to deploy Cloud Access Connectors in a user's cloud environment. __Note: These scripts are suitable for creating reference deployments for demonstration, evaluation, or development purposes. The infrastructure created may not meet the reliability, availability, or security requirements of your organization.__

# Documentation
- [Instructions](docs/aws/README.md) for deploying CAS on Amazon Web Services
- [Instructions](docs/gcp/README.md) for deploying CAS on Google Cloud Platform

CAS deployments on Microsoft Azure is available in a separate repository. Please visit https://github.com/teradici/Azure_Deployments

# Directory structure
## deployments/
The top level terraform scripts that creates entire deployments.

## docs/
Description and instructions for deployments on different clouds.

## modules/
The building blocks of deployments, e.g. a Domain Controller, a Cloud Access
Connector, a Workstation, etc.

## quickstart/
Contains the Quickstart Tutorial and Python scripts for a quick deployment using Google Cloud Shell.

## tools/
Various scripts to help with Terraform deployments.  e.g. a Python script to
generate random users for an Active Directory in a CSV file.

# Maintainer
If any security issues or bugs are found, or if there are feature requests, please contact Sherman Yin at syin@teradici.com
