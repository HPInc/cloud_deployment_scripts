# Cloud Access Software

Teradici CAS (Cloud Access Software) delivers a highly responsive remote desktop experience with color-accurate, lossless and distortion-free graphics – even for high frame rate 4K/UHD graphics workloads. This is exactly why artists, editors, producers, architects, and designers all trust CAS to provide the resolution, sound, and color fidelity they need to create and work from anywhere. The immersive, feature-rich experience that CAS delivers is the reason why we won an Engineering Emmy in 2020.

Based on our secure PCoIP® (PC-over-IP) protocol that connects over 15 million endpoints around the globe, CAS makes all the magic happen for Windows, Linux and macOS (coming soon) desktops and applications through three core software components:

- **PCoIP Agents** in any standalone or virtualized workstation, on-prem data center, cloud, multicloud or hybrid host environment
- **CAS Manager** to secure, broker, and provision Teradici CAS connections
- **PCoIP Clients** to enable any PCoIP Zero Client, PCoIP-Enabled Thin Client, PC, Mac, laptop, or tablet to access their remote desktops, fixed or mobile workstations from anywhere

For more details, please visit https://teradici.com.

This repository contains a collection of Terraform configurations for demonstrating how to deploy CAS Manager and Cloud Access Connectors in a user's cloud environment. __Note: These configurations are suitable for creating reference deployments for demonstration, evaluation, or development purposes. The infrastructure created may not meet the reliability, availability, or security requirements of your organization.__

# Documentation
- [Instructions](docs/aws/README.md) for deploying CAS on Amazon Web Services
- [Instructions](docs/gcp/README.md) for deploying CAS on Google Cloud Platform

CAS deployments on Microsoft Azure is available in a separate repository. Please visit https://github.com/teradici/Azure_Deployments

# Directory structure
## deployments/
The top level Terraform configuration that creates entire deployments.

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
