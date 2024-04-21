output "managed_node_ips" {
  value = [for instance in aws_instance.inventory_nodes : instance.public_ip]
}