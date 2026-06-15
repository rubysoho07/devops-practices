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

data "aws_subnet" "public_subnet_c" {
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

resource "aws_instance" "k3s_single" {
  count                  = var.k3s_mode == "single" ? 1 : 0
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_single"
  }
}

resource "aws_instance" "k3s_multi_server" {
  count                  = var.k3s_mode == "multi" ? 1 : 0
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_multi_server"
  }
}

resource "aws_instance" "k3s_multi_agent" {
  count                  = var.k3s_mode == "multi" ? 2 : 0
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name = "k3s_multi_agent"
  }
}

resource "aws_instance" "k3s_ha_server" {
  count                  = var.k3s_mode == "ha" ? 3 : 0
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = "t4g.small"
  subnet_id              = data.aws_subnet.public_subnet.id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]

  tags = {
    Name  = "k3s-ha-server-${count.index}"
    Group = "k3s"
  }
}

resource "aws_lb_target_group" "k3s_ha_server" {
  count    = var.k3s_mode == "ha" ? 1 : 0
  name     = "k3s-ha-server"
  port     = 6443
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "k3s_ha_server" {
  count            = var.k3s_mode == "ha" ? 3 : 0
  target_group_arn = aws_lb_target_group.k3s_ha_server[0].arn
  target_id        = aws_instance.k3s_ha_server[count.index].id
  port             = 6443
}

resource "aws_lb" "k3s_ha_nlb" {
  count              = var.k3s_mode == "ha" ? 1 : 0
  name               = "k3s-ha-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [data.aws_subnet.public_subnet.id, data.aws_subnet.public_subnet_c.id]

  tags = {
    Name = "k3s-ha-nlb"
  }
}

resource "aws_lb_listener" "k3s_ha_nlb_6443" {
  count             = var.k3s_mode == "ha" ? 1 : 0
  load_balancer_arn = aws_lb.k3s_ha_nlb[0].arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_ha_server[0].arn
  }
}

output "k3s_ha_nlb_dns_name" {
  value = var.k3s_mode == "ha" ? aws_lb.k3s_ha_nlb[0].dns_name : ""
}
