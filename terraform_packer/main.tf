terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "aws_ami" "packer" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Name"
    values = ["al2023-ansible"]
  }
}

data "aws_iam_role" "ssm" {
  name = "ec2-instance-ssm-role"
}

resource "aws_instance" "instance_1" {
  ami           = data.aws_ami.packer.id
  instance_type = "t3.micro"
  iam_instance_profile = data.aws_iam_role.ssm.name

  user_data = <<EOF
#!/bin/bash
echo "Hello, World!" > /home/ec2-user/testfile.txt
EOF

  tags = {
    Name = "instance-1"
  }
}

resource "aws_instance" "instance_2" {
  ami           = data.aws_ami.packer.id
  instance_type = "t3.micro"
  iam_instance_profile = data.aws_iam_role.ssm.name

  user_data = <<EOF
#!/bin/bash
echo "Goodbye, World!" > /home/ec2-user/testfile.txt
EOF

  tags = {
    Name = "instance-2"
  }
}