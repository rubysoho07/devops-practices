variable "keypair_name" {
  type        = string
  description = "SSH Key Pair name"
}

variable "k3s_mode" {
  type        = string
  description = "Server mode for k3s"
  default     = "single"

  validation {
    condition     = contains(["single", "multi", "ha"], var.k3s_mode)
    error_message = "Available values: 'single', 'multi', 'ha'"
  }
}
