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
  # Obrigatorio desde 1.0.2: tenancies com Identity Domains recusam CreateUser sem e-mail
  # (400 IdcsConversionError "The primary email must be specified") e o Apply quebrava pela metade.
  description = "E-mail do usuario de servico (obrigatorio)"
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+$", trimspace(var.service_user_email)))
    error_message = "service_user_email e obrigatorio (ex.: cloud@empresa.com.br)."
  }
}

variable "helper_vcn_cidr" {
  description = "CIDR da VCN isolada da VM auxiliar (so precisa mudar se colidir com alguma rede pareada)"
  type        = string
  default     = "10.254.254.0/28"

  validation {
    condition     = can(cidrhost(var.helper_vcn_cidr, 0))
    error_message = "helper_vcn_cidr precisa ser um CIDR IPv4 valido (ex.: 10.254.254.0/28)."
  }
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
