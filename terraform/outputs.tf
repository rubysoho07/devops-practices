output "control_node_ip" {
  value = aws_instance.control_node.public_ip
}

output "managed_node_ips" {
  value = [for instance in aws_instance.managed_nodes : instance.public_ip]
}