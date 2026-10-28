terraform {
  required_version = ">= 1.2.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    # Só é usado com enable_callback = true (H2). Terraform não permite declarar provider condicional.
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}

provider "oci" {
  region = var.region
}
