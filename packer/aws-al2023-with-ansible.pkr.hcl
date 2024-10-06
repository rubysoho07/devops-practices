packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }

    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = formatdate("YYMMDD_hhmmss", timestamp())
}

source "amazon-ebs" "al2023_ansible" {
  ami_name      = "al2023-ansible-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "ap-northeast-2"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  
  ssh_username = "ec2-user"
}

build {
  name = "al2023-ansible-test"
  sources = [
    "source.amazon-ebs.al2023_ansible"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/playbook_for_packer.yaml"
  }
}