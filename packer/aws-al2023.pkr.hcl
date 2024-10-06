packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "al2023" {
  ami_name      = "learn-packer-linux-aws-gonigoni"
  instance_type = "t2.micro"
  region        = "ap-northeast-2"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023*-kernel-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
  ssh_username = "ec2-user"
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.al2023"
  ]
}
