terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# Data sources for subnets
data "aws_subnet" "public_2a" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC-2A"]
  }
}

data "aws_subnet" "public_2b" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC-2B"]
  }
}

data "aws_subnet" "public_2c" {
  filter {
    name   = "tag:Name"
    values = ["PUBLIC-2C"]
  }
}

locals {
  subnet_ids = [
    data.aws_subnet.public_2a.id,
    data.aws_subnet.public_2b.id,
    data.aws_subnet.public_2c.id
  ]
}

# Data source for Amazon Linux 2023 AMI
data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security Group for MongoDB
resource "aws_security_group" "mongodb_sg" {
  name        = "mongodb-replica-set"
  description = "Security group for MongoDB replica set"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongodb-replica-set-sg"
  }
}

# EC2 instances for MongoDB replica set
resource "aws_instance" "mongodb" {
  count                  = 3
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "m5.large"
  key_name               = "gonigoni-aws-apn2-20251105"
  subnet_id              = local.subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]

  tags = {
    Name    = "mongodb-replica-${count.index + 1}"
    Service = "MongoDB"
  }
}

# Output instance information
output "mongodb_instances" {
  value = {
    for i, instance in aws_instance.mongodb :
    "mongodb-${i + 1}" => {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}
