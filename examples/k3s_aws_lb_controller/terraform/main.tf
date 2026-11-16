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

locals {
  # Ansible Inventory(tag:Group)와 AWS Load Balancer Controller의 clusterName이 이 값을 사용합니다.
  cluster_name = "k3s-aws-lbc"

  # 노드를 배치하고, ALB/NLB를 생성할 Public Subnet
  # (ALB는 서로 다른 AZ의 서브넷이 2개 이상 필요하며, 노드가 있는 AZ를 모두 포함해야 합니다)
  public_subnet_names = ["PUBLIC-2A", "PUBLIC-2B", "PUBLIC-2C"]
  public_subnet_ids   = [for name in local.public_subnet_names : data.aws_subnet.public[name].id]

  # AWS Cloud Controller Manager가 클러스터에 속한 리소스를 식별할 때 사용하는 태그
  cluster_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public" {
  for_each = toset(local.public_subnet_names)
  vpc_id   = data.aws_vpc.default.id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# AWS Load Balancer Controller가 internet-facing 로드밸런서를 만들 서브넷을 찾을 때 사용하는 태그
# 참고자료: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/
resource "aws_ec2_tag" "public_subnet_elb_role" {
  for_each    = data.aws_subnet.public
  resource_id = each.value.id
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = local.public_subnet_ids[0]
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  # AWS Load Balancer Controller Pod가 IMDSv2로 인스턴스 프로파일 자격 증명을 가져오려면
  # hop limit이 2 이상이어야 합니다. (Pod 네트워크를 거치면서 hop이 1 늘어남)
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = merge(local.cluster_tags, {
    Name  = "${local.cluster_name}-server"
    Group = local.cluster_name
    Role  = "server"
  })

  # 새 AMI가 배포되어도 인스턴스가 교체되지 않도록 합니다.
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "k3s_agent" {
  count                  = 2
  ami                    = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = local.public_subnet_ids[(count.index + 1) % length(local.public_subnet_ids)]
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.k3s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = merge(local.cluster_tags, {
    Name  = "${local.cluster_name}-agent-${count.index}"
    Group = local.cluster_name
    Role  = "agent"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

output "k3s_server_public_ip" {
  value = aws_instance.k3s_server.public_ip
}

output "k3s_agent_public_ips" {
  value = aws_instance.k3s_agent[*].public_ip
}
