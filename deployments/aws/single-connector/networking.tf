/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = {
    Name = "${local.prefix}${var.vpc_name}"
  }
}

resource "aws_subnet" "dc-subnet" {
  cidr_block = var.dc_subnet_cidr
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}subnet-dc"
  }
}

resource "aws_subnet" "cac-subnet" {
  cidr_block = var.cac_subnet_cidr
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}subnet-cac"
  }
}

resource "aws_subnet" "ws-subnet" {
  cidr_block = var.ws_subnet_cidr
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}subnet-ws"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}igw"
  }
}

resource "aws_eip" "nat-ip" {
  vpc      = true

  tags = {
    Name = "${local.prefix}nat-ip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = aws_subnet.cac-subnet.id

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

resource "aws_route_table_association" "rt-cac" {
  subnet_id      = aws_subnet.cac-subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "rt-ws" {
  subnet_id      = aws_subnet.ws-subnet.id
  route_table_id = aws_route_table.private.id
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "allow-ssh" {
  name   = "allow-ssh"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-ssh"
  }
}

resource "aws_security_group" "allow-http" {
  name   = "allow-http"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-http"
  }
}

resource "aws_security_group" "allow-rdp" {
  name   = "allow-rdp"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "udp"
    from_port   = 3389
    to_port     = 3389
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-rdp"
  }
}

resource "aws_security_group" "allow-winrm" {
  name   = "allow-winrm"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 5986
    to_port     = 5986
    cidr_blocks = ["0.0.0.0/0"]
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
  name   = "allow-icmp"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = 8
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-icmp"
  }
}

resource "aws_security_group" "allow-pcoip" {
  name   = "allow-pcoip"
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 4172
    to_port     = 4172
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "udp"
    from_port   = 4172
    to_port     = 4172
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}secgrp-allow-pcoip"
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name      = replace("${local.prefix}${var.domain_name}-endpoint", ".", "-")
  direction = "OUTBOUND"

  security_group_ids = [
    data.aws_security_group.default.id,
  ]

  ip_address {
    subnet_id = aws_subnet.dc-subnet.id
  }

  # TODO: Terraform errors out with "ip_address: attribute supports 2 item as a
  # minimum, config has 1 declared" without the second ip_address block with a
  # different subnet.
  ip_address {
    subnet_id = aws_subnet.cac-subnet.id
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
    ip = var.dc_private_ip
  }

  tags = {
    Name = "${local.prefix}${var.domain_name}-rule"
  } 
}

resource "aws_route53_resolver_rule_association" "association" {
  resolver_rule_id = aws_route53_resolver_rule.rule.id
  vpc_id           = aws_vpc.vpc.id
}
