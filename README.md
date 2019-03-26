This repo contains Terraform scripts for creating various Cloud Access Manager
deployment scenarios in the cloud.

# Directory structure
## deployments/
The top level terraform scripts that creates entire deployments. 

## modules/
The building blocks of deployments, e.g. a Domain Controller, a Cloud Access
Connector, a Workstation, etc.

# Deployments
## dc-cac-ws
Creates a VPC with 3 subnets in the same region. The subnets are
- subnet-dc : for the Domain Controller
- subnet-cac: for the Connector
- subnet-ws : for the workstations
Firewall rules are created to allow wide-open access within the VPC, and
selected ports are open to the world for operation and for debug purposes.

A Domain Controller is created with Active Directory, DNS and LDAP-S configured.
2 users are set up in the new domain: Administrator and cam_admin (default). It
is also given a static IP.

A Cloud Access Connector is created and registers itself with the CAM service
with the given Token and PCoIP Registration code.

Domain-joined Windows Graphics workstation(s) and CentOS Graphics
workstation(s) are optionally created, specified by win_gfx_ws_count and
centos_gfx_ws_count (both default to 0).  These workstations are created with
NVidia graphics driver and PCoIP Agent installed.

At the end of the deployment (~20 mins), a user should be able to go to the CAM
Admin Console and see the new connector added, and the newly created
workstations available for selection when adding existing remote workstation.

## dc-lb-cac-ws
Same as dc-cac-ws, except the number of Connectors can be specified, and all the
connectors are added to a Target Pool of a TCP Network Load Balancer. 

## dc-only
A simple deployment of one Domain Controller, intended for testing Domain Controller operations.

Creates one VPC, one subnet and a single Domain Controller with ports opened
for ICMP, RDP and WinRM.  Domain Controller is configured with Acitve
Directory, DNS, LDAP-S.  One AD Service Account is also created.