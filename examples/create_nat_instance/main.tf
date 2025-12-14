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

# Amazon Linux 2023 AMI for ARM64
data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# Default VPC data
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

# Security Groups for NAT instance with recommended rules
resource "aws_security_group" "nat_instance_sg" {
  name        = "nat-instance-sg"
  description = "Security group for NAT instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow inbound traffic from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elastic IP
resource "aws_eip" "nat_instance_eip" {
  domain = "vpc"

  tags = {
    Name = "NAT-Instance-EIP"
  }
}

# t4g.small EC2 instance with source/destination check disabled
resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_2a.id
  vpc_security_group_ids = [aws_security_group.nat_instance_sg.id]
  key_name               = "your-key-pair-name" # Replace with your actual key pair name

  source_dest_check = false

  tags = {
    Name = "NAT-Instance"
  }
}

# Associate Elastic IP with NAT instance
resource "aws_eip_association" "nat_instance_eip_assoc" {
  instance_id   = aws_instance.nat_instance.id
  allocation_id = aws_eip.nat_instance_eip.id
}

