terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">=5.46.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "ap-northeast-2"
}

# resource "aws_instance" "managed_node" {
#   ami = data.aws_ssm_parameter.amazon_linux_2023_ami.value
#   instance_type = "t3.micro"
# }

resource "aws_instance" "inventory_nodes" {
  count = 3
  ami = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type = "t3.micro"
  subnet_id = data.aws_subnets.public.ids[count.index % length(data.aws_subnets.public.ids)]
  vpc_security_group_ids = [ var.security_group_id ]
  key_name = var.ssh_key_name

  tags = {
    Name = "Ansible-Test-${count.index}"
  }
}