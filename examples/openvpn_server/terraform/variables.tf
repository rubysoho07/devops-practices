variable "keypair_name" {
  type        = string
  description = "Name of SSH key pair"
}

variable "openvpn_inbound_cidr" {
  type        = string
  description = "Inbound IP CIDR for OpenVPN Server"
}
