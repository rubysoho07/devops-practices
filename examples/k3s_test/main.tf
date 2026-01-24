terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "aws_subnet" "public_subnet" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC-2A"]
  }
}

data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "k3s_nodes" {
  name        = "k3s_nodes"
  description = "Security group for k3s nodes"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "k3s_nodes"
  }
}

resource "aws_security_group_rule" "k3s_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_instance" "k3s_single" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = "your_key_pair"
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_single"
  }
}

resource "aws_instance" "k3s_multi_server" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = "your_key_pair"
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_multi_server"
  }
}

resource "aws_instance" "k3s_multi_agent" {
  count                  = 2
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = "your_key_pair"
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_multi_agent"
  }
}
