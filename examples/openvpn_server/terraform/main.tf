terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.26.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public_2a" {
  # Filter by tag
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "tag:Name"
    values = ["PUBLIC-2A"]
  }
}

data "aws_subnet" "private_2a" {
  # Filter by tag
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "tag:Name"
    values = ["PRIVATE-2A"]
  }
}

# Security Groups for OpenVPN server with recommended rules
resource "aws_security_group" "openvpn_server_sg" {
  name        = "openvpn-server-sg"
  description = "Security group for OpenVPN server"
  vpc_id      = data.aws_vpc.default.id
}

# Allow inbound traffic on UDP port 1194 for OpenVPN
resource "aws_security_group_rule" "openvpn_udp_1194_inbound" {
  type              = "ingress"
  from_port         = 1194
  to_port           = 1194
  protocol          = "udp"
  cidr_blocks       = [var.openvpn_inbound_cidr]
  security_group_id = aws_security_group.openvpn_server_sg.id
}

# Allow inbound traffic for SSH connection
resource "aws_security_group_rule" "ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.openvpn_inbound_cidr]
  security_group_id = aws_security_group.openvpn_server_sg.id
}

# Allow all outbound traffic for VPC
resource "aws_security_group_rule" "allow_all_vpc_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.default.cidr_block]
  security_group_id = aws_security_group.openvpn_server_sg.id
}

# Allow all outbound traffic on HTTPS
resource "aws_security_group_rule" "allow_https_outbound" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openvpn_server_sg.id
}

# Allow all outbound traffic on HTTP
resource "aws_security_group_rule" "allow_http_outbound" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.openvpn_server_sg.id
}

# EC2 instance for OpenVPN server
resource "aws_instance" "openvpn_server" {
  ami                    = "ami-00ae06c981dd2a581" # Rocky Linux 9 for aarch64 (Seoul Region)
  instance_type          = "t4g.small"
  key_name               = var.keypair_name
  subnet_id              = data.aws_subnet.public_2a.id
  vpc_security_group_ids = [aws_security_group.openvpn_server_sg.id]
  source_dest_check      = false

  tags = {
    Name = "OpenVPN"
  }
}

# Elastic IP for OpenVPN server
resource "aws_eip" "openvpn_server_eip" {
  domain = "vpc"

  tags = {
    Name = "OpenVPN-EIP"
  }
}

# EIP and EC2 instance association
resource "aws_eip_association" "openvpn_server_eip_association" {
  instance_id   = aws_instance.openvpn_server.id
  allocation_id = aws_eip.openvpn_server_eip.id
}

# Security group for test server
resource "aws_security_group" "test_server_sg" {
  name        = "test-server-sg"
  description = "Security group for test server"
  vpc_id      = data.aws_vpc.default.id
}

# Allow all traffic from OpenVPN server
resource "aws_security_group_rule" "allow_all_from_openvpn_server" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.test_server_sg.id
  source_security_group_id = aws_security_group.openvpn_server_sg.id
}

# Test server in private subnet
resource "aws_instance" "test_server" {
  ami                    = "ami-00ae06c981dd2a581" # Rocky Linux 9 for aarch64 (Seoul Region)
  instance_type          = "t4g.small"
  key_name               = var.keypair_name
  subnet_id              = data.aws_subnet.private_2a.id
  vpc_security_group_ids = [aws_security_group.test_server_sg.id]

  tags = {
    Name = "Test-Server"
  }
}
