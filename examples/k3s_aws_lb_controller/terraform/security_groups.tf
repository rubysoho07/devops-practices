# AWS Load Balancer Controller는 로드밸런서 -> NodePort 트래픽을 허용하는 규칙을 이 보안 그룹에 직접 추가합니다.
# 보안 그룹에 인라인 ingress 블록을 쓰면 Terraform이 그 규칙을 지워버리므로, 규칙은 aws_security_group_rule로 분리합니다.
resource "aws_security_group" "k3s_nodes" {
  name        = "${local.cluster_name}-nodes"
  description = "Security group for k3s nodes (AWS Load Balancer Controller example)"
  vpc_id      = data.aws_vpc.default.id

  tags = merge(local.cluster_tags, {
    Name = "${local.cluster_name}-nodes"
  })
}

resource "aws_security_group_rule" "k3s_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.k3s_nodes.id
}

resource "aws_security_group_rule" "k3s_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.k3s_nodes.id
}

# 노드 간 통신: Kubernetes API(6443/tcp), kubelet(10250/tcp), Flannel VXLAN(8472/udp) 등
resource "aws_security_group_rule" "k3s_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
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
