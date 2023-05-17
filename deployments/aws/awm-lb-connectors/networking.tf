/*
 * Copyright Teradici Corporation 2020-2021; © Copyright 2021-2023 HP Development Company, L.P
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "http" "myip" {
  url = "https://cas.teradici.com/api/v1/health"
}

locals {
  myip                = "${chomp(data.http.myip.response_headers.Client-Ip)}/32"
  vpc_uid             = "${local.prefix}${var.vpc_name}"
  allowed_admin_cidrs = distinct(concat([local.myip], var.allowed_admin_cidrs))
}

data "aws_availability_zones" "available_az" {
  state            = "available"
  exclude_zone_ids = var.az_id_exclude_list
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

resource "aws_vpc" "vpc" {
  cidr_block         = var.vpc_cidr
  enable_dns_support = true
  # Required to set dns hostname enabled 
  # https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html#create-interface-endpoint
  enable_dns_hostnames = true

  tags = {
    Name = local.vpc_uid
  }
}

resource "aws_subnet" "dc-subnet" {
  cidr_block        = var.dc_subnet_cidr
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available_az.names[0]

  tags = {
    Name = "${local.prefix}${var.dc_subnet_name}"
  }
}

resource "aws_subnet" "awm-subnet" {
  cidr_block        = var.awm_subnet_cidr
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available_az.names[0]

  tags = {
    Name = "${local.prefix}${var.awm_subnet_name}"
  }
}

resource "aws_subnet" "awc-subnets" {
  count = length(var.awc_subnet_cidr_list)

  cidr_block        = var.awc_subnet_cidr_list[count.index]
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.awc_zone_list[count.index]

  tags = {
    Name = "${local.prefix}${var.awc_subnet_name}-${var.awc_zone_list[count.index]}"
  }
}

resource "aws_subnet" "ws-subnet" {
  cidr_block        = var.ws_subnet_cidr
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available_az.names[0]

  tags = {
    Name = "${local.prefix}${var.ws_subnet_name}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}igw"
  }
}

resource "aws_eip" "nat-ip" {
  vpc = true

  tags = {
    Name = "${local.prefix}nat-ip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = aws_subnet.awc-subnets[0].id

  tags = {
    Name = "${local.prefix}nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.prefix}rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${local.prefix}rt-private"
  }
}

resource "aws_route_table_association" "rt-dc" {
  subnet_id      = aws_subnet.dc-subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt-awm" {
  subnet_id      = aws_subnet.awm-subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt-awc" {
  count = length(var.awc_subnet_cidr_list)

  subnet_id      = aws_subnet.awc-subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt-ws" {
  subnet_id      = aws_subnet.ws-subnet.id
  route_table_id = aws_route_table.private.id
}

# [EC2.2] The VPC default security group should not allow inbound and outbound traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id

  # ingress {
  #   # removing all ingress rules to satisfy [EC2.2]
  # }

  # egress {
  #   # removing all egress rules to satisfy [EC2.2]
  # }
}

# Create security groups to allow all inbound and outbound traffic for communication between instances
resource "aws_security_group" "allow-internal" {
  name   = "${local.prefix}allow-internal"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-internal"
  }
}

resource "aws_security_group" "allow-http" {
  name   = "${local.prefix}allow-http"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = local.allowed_admin_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = local.allowed_admin_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-http"
  }
}

resource "aws_security_group" "allow-ssh" {
  name   = "${local.prefix}allow-ssh"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = local.allowed_admin_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-ssh"
  }
}

resource "aws_security_group" "allow-rdp" {
  name   = "${local.prefix}allow-rdp"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = local.allowed_admin_cidrs
  }

  ingress {
    protocol    = "udp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = local.allowed_admin_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-rdp"
  }
}

resource "aws_security_group" "allow-winrm" {
  name   = "${local.prefix}allow-winrm"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 5986
    to_port     = 5986
    cidr_blocks = local.allowed_admin_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-winrm"
  }
}

# In the case of ICMP, from_port is ICMP type, to_port is ICMP code. Type 8
# Code 0 is Echo Request.
# https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-security-group-ingress.html
# https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml

resource "aws_security_group" "allow-icmp" {
  name   = "${local.prefix}allow-icmp"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = 8
    to_port     = 0
    cidr_blocks = local.allowed_admin_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-icmp"
  }
}

resource "aws_security_group" "allow-pcoip" {
  name   = "${local.prefix}allow-pcoip"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.allowed_client_cidrs
  }

  ingress {
    protocol    = "tcp"
    from_port   = 4172
    to_port     = 4172
    cidr_blocks = var.allowed_client_cidrs
  }

  ingress {
    protocol    = "udp"
    from_port   = 4172
    to_port     = 4172
    cidr_blocks = var.allowed_client_cidrs
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-pcoip"
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name      = replace("${local.prefix}${var.domain_name}-endpoint", ".", "-")
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.allow-internal.id,
  ]

  ip_address {
    subnet_id = aws_subnet.dc-subnet.id
  }

  # TODO: Terraform errors out with "ip_address: attribute supports 2 item as a
  # minimum, config has 1 declared" without the second ip_address block with a
  # different subnet.
  ip_address {
    subnet_id = aws_subnet.awc-subnets[0].id
  }

  tags = {
    Name = "${local.prefix}${var.domain_name}-endpoint"
  }
}

resource "aws_route53_resolver_rule" "rule" {
  domain_name = var.domain_name
  name        = replace("${local.prefix}${var.domain_name}-forwarder", ".", "-")

  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = module.dc.internal-ip
  }

  tags = {
    Name = "${local.prefix}${var.domain_name}-rule"
  }
}

resource "aws_route53_resolver_rule_association" "association" {
  resolver_rule_id = aws_route53_resolver_rule.rule.id
  vpc_id           = aws_vpc.vpc.id
}

# [EC2.10] Amazon EC2 should be configured to use VPC endpoints that are created for the Amazon EC2 service
# Severity: Medium
resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type = "Interface"

  # Select one subnet per Availability Zone from which you'll access the AWS service
  # https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html#create-interface-endpoint
  subnet_ids = aws_subnet.awc-subnets[*].id
  security_group_ids = [
    aws_security_group.allow-internal.id,
    aws_security_group.allow-http.id # allow inbound HTTPs traffic
  ]

  tags = {
    Name = "${local.prefix}ec2-interface-endpoint"
  }
}

# [EC2.6] VPC flow logging should be enabled in all VPCs
# Severity: Medium -> Capture all rejected traffic and store the data in cloudwatch logs
resource "aws_flow_log" "vpc" {
  count = var.cloudwatch_enable ? 1 : 0
  # iam_role_arn    = time_sleep.iam_assume_role.triggers["iam_role_arn"]
  iam_role_arn    = aws_iam_role.vpc[count.index].arn
  log_destination = aws_cloudwatch_log_group.vpc[count.index].arn
  traffic_type    = "REJECT"
  vpc_id          = aws_vpc.vpc.id
}

# Cloudwatch logs for vpc flow log
# Each network interface has a unique log stream in the log group.
resource "aws_cloudwatch_log_group" "vpc" {
  count = var.cloudwatch_enable ? 1 : 0

  name = "${local.prefix}${aws_vpc.vpc.id}"
  # retention_in_days = 14
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "vpc" {
  count = var.cloudwatch_enable ? 1 : 0

  name               = local.vpc_uid
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json
}

data "aws_iam_policy_document" "flow_log_policy" {
  statement {
    sid = "AWSVPCFlowLogsPushToCloudWatch"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy" "vpc" {
  count = var.cloudwatch_enable ? 1 : 0

  name   = local.vpc_uid
  role   = aws_iam_role.vpc[count.index].id
  policy = data.aws_iam_policy_document.flow_log_policy.json
}

# [EC2.21] Network ACLs should not allow ingress from 0.0.0.0/0 to port 22 or port 3389
# Severity: Medium
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id

  # no rules defined, deny all traffic in this default ACL
  # use custome nacl instead
}

resource "aws_network_acl" "nacls-awc" {
  count = length(aws_subnet.awc-subnets)

  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.awc-subnets[count.index].id]

  # allow-ssh
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 100 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  # allow-icmp
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 200 + ingress.key
      protocol   = "icmp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0 # not applicable for ICMP but required by Terraform
      to_port    = 0 # not applicable for ICMP but required by Terraform
      # In the case of ICMP, Type 8, code 0 is for Echo Request
      # https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml#icmp-parameters-codes-8
      icmp_type = 8
      icmp_code = 0
    }
  }

  # allow-pcoip
  dynamic "ingress" {
    for_each = var.allowed_client_cidrs

    content {
      rule_no    = 300 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 443
      to_port    = 443
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_client_cidrs

    content {
      rule_no    = 400 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 4172
      to_port    = 4172
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_client_cidrs

    content {
      rule_no    = 500 + ingress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 4172
      to_port    = 4172
    }
  }

  # allow-internal
  ingress {
    protocol   = -1
    rule_no    = 1000
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # [EC2.21] Network ACLs should not allow ingress from 0.0.0.0/0 to
  # port 22 or port 3389
  ingress {
    protocol   = "tcp"
    rule_no    = 2000
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  # Ephemeral ports for clients to initiate traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 3000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.prefix}nacls-awc-${count.index}"
  }
}

resource "aws_network_acl" "nacls-awm" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.awm-subnet.id]

  # allow-http
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 10 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 80
      to_port    = 80
    }
  }

  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 20 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 443
      to_port    = 443
    }
  }

  # allow-ssh
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 100 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  # allow-icmp
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 200 + ingress.key
      protocol   = "icmp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0 # not applicable for ICMP but required by Terraform
      to_port    = 0 # not applicable for ICMP but required by Terraform
      # In the case of ICMP, Type 8, code 0 is for Echo Request
      # https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml#icmp-parameters-codes-8
      icmp_type = 8
      icmp_code = 0
    }
  }

  # allow-internal
  ingress {
    protocol   = -1
    rule_no    = 1000
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # [EC2.21] Network ACLs should not allow ingress from 0.0.0.0/0 to
  # port 22 or port 3389
  ingress {
    protocol   = "tcp"
    rule_no    = 2000
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  # Ephemeral ports for clients to initiate traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 3000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.prefix}nacls-awm"
  }
}

resource "aws_network_acl" "nacls-dc" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.dc-subnet.id]

  # allow-rdp
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 100 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3389
      to_port    = 3389
    }
  }

  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 200 + ingress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3389
      to_port    = 3389
    }
  }

  # allow-winrm (upload-scripts)
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 300 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 5986
      to_port    = 5986
    }
  }

  # allow-icmp
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 400 + ingress.key
      protocol   = "icmp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0 # not applicable for ICMP but required by Terraform
      to_port    = 0 # not applicable for ICMP but required by Terraform
      # In the case of ICMP, Type 8, code 0 is for Echo Request
      # https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml#icmp-parameters-codes-8
      icmp_type = 8
      icmp_code = 0
    }
  }

  # allow-internal
  ingress {
    protocol   = -1
    rule_no    = 1000
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # [EC2.21] Network ACLs should not allow ingress from 0.0.0.0/0 to
  # port 22 or port 3389
  ingress {
    protocol   = "tcp"
    rule_no    = 2000
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  # Ephemeral ports for clients to initiate traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 3000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.prefix}nacls-dc"
  }
}

resource "aws_network_acl" "nacls-ws" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.ws-subnet.id]

  # allow-ssh for centos 
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs

    content {
      rule_no    = 90 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 22
      to_port    = 22
    }
  }

  # allow-rdp for windows
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 100 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3389
      to_port    = 3389
    }
  }

  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 200 + ingress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3389
      to_port    = 3389
    }
  }

  # allow-icmp
  dynamic "ingress" {
    for_each = local.allowed_admin_cidrs
    content {
      rule_no    = 300 + ingress.key
      protocol   = "icmp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 0 # not applicable for ICMP but required by Terraform
      to_port    = 0 # not applicable for ICMP but required by Terraform
      # In the case of ICMP, Type 8, code 0 is for Echo Request
      # https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml#icmp-parameters-codes-8
      icmp_type = 8
      icmp_code = 0
    }
  }

  # allow-internal
  ingress {
    protocol   = -1
    rule_no    = 1000
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # [EC2.21] Network ACLs should not allow ingress from 0.0.0.0/0 to
  # port 22 or port 3389
  ingress {
    protocol   = "tcp"
    rule_no    = 2000
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  # Ephemeral ports for clients to initiate traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 3000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.prefix}nacls-ws"
  }
}
