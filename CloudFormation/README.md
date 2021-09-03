# CloudFormation Templates
## Introduction
This directory contains CloudFormation templates and related scripts for deploying Teradici CAS components on AWS. These templates can be downloaded and optionally modified before use.

__Note: These templates are suitable for creating reference deployments for demonstration, evaluation, or development purposes. The infrastructure created may not meet the reliability, availability, or security requirements of your organization.__

CloudFormation templates can be uploaded to the AWS CloudFormation via the console at https://console.aws.amazon.com/cloudformation/home or used with the AWS CLI. If no modifications are needed, a copy of these templates are also available on S3 location "https://teradici-public.s3.amazonaws.com/CloudFormation/{template name}"; this location can be referenced directly when using AWS CloudFormation console.

For more information about CloudFormation, please visit https://aws.amazon.com/cloudformation/

## List of Templates
- [CAS Manager with AWS integrations](#casmanager.yaml)
---
## CASManager.yaml
Creates a Teradici CAS Manager server along with a HashiCorp Vault server (using DynamoDB as the storage backend) and a Document DB cluster as the Vault and Database backends for CAS Manager, respectively. All passwords are generated and stored in AWS Secrets Manager. Please see the "Output" tab in CloudFormation for URL and initial password for the CAS Manager. Creation time is approximately 25 mins.

For more information about CAS Manager, please visit https://www.teradici.com/web-help/cas_manager/current/
### Requirements
- must be used in a region where Document DB is available
- must be deployed in an existing VPC with at least 1 public subnet and another subnet in a different Availability Zone
- an existing EC2 Key pair

### Quick create stack
https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://teradici-public.s3.amazonaws.com/CloudFormation/CASManager/CASManager.yaml&stackName=casm
