packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }

    azure = {
      version = "~> 2"
      source  = "github.com/hashicorp/azure"
    }
  }
}

locals {
  timestamp = formatdate("YYMMDD_hhmmss", timestamp())
}

source "azure-arm" "azure_rocky_ansible" {
  # Auth with Azure CLI
  use_azure_cli_auth = true

  # Required
  image_publisher = "resf"
  image_offer     = "rockylinux-x86_64"
  image_sku       = "9-base"
  # Default Version: Latest (If you want to specify OS version, add `image_version = "..."`)

  location = "Korea Central"

  managed_image_name                 = "gonigoni-rocky9-${local.timestamp}"
  managed_image_resource_group_name  = "gonigoni-rg"
  managed_image_storage_account_type = "Premium_LRS"

  # Optional
  plan_info {
    plan_name      = "9-base"
    plan_product   = "rockylinux-x86_64"
    plan_publisher = "resf"
  }

  os_type = "Linux"
  vm_size = "Standard_D2as_v6"
}

build {
  sources = ["sources.azure-arm.azure_rocky_ansible"]

  provisioner "ansible" {
    playbook_file = "../../ansible/playbook_for_packer.yaml"
  }
}