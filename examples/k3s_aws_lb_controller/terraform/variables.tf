variable "keypair_name" {
  type        = string
  description = "SSH Key Pair name"
}

variable "instance_type" {
  type        = string
  description = "Instance type for k3s nodes (arm64)"
  default     = "t4g.small"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH (22) and the Kubernetes API (6443)"
  default     = ["0.0.0.0/0"]
}
