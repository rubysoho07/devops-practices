resource "aws_security_group" "managed_nodes" {
  name        = "ansible_managed_nodes"
  description = "Ansible managed nodes"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type                     = "ingress"
  security_group_id        = aws_security_group.managed_nodes.id
  source_security_group_id = var.security_group_id
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.managed_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.managed_nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
}
