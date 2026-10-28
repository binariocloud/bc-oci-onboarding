variable "tenancy_ocid" {
  description = "Preenchido pelo Resource Manager"
  type        = string
}

variable "region" {
  description = "Preenchido pelo Resource Manager"
  type        = string
}

variable "onboarding_code" {
  description = "Codigo publico enviado pela Binario Cloud (ID do onboarding + chave PUBLICA + fingerprint)"
  type        = string

  validation {
    condition     = can(jsondecode(base64decode(var.onboarding_code)).bc_public_key_pem)
    error_message = "onboarding_code invalido: cole exatamente o codigo enviado pela Binario Cloud."
  }
}

variable "source_compartment_ocid" {
  description = "Compartment das VMs a migrar"
  type        = string
}

variable "parent_compartment_ocid" {
  description = "Onde criar o compartment bc-migration-<id> (vazio = raiz do tenancy)"
  type        = string
  default     = ""
}

variable "service_user_email" {
  description = "E-mail do usuario de servico (exigido em tenancies com Identity Domains; vazio = sem e-mail)"
  type        = string
  default     = ""
}

variable "enable_callback" {
  description = "H2 (PROVISORIA): envia os outputs a API da Binario Cloud. Desligado por padrao"
  type        = bool
  default     = false
}

variable "callback_url" {
  description = "URL do endpoint /v1/migration/oci/onboarding-callback (so com enable_callback)"
  type        = string
  default     = ""
}
