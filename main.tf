# Pacote generico do botao "Deploy to Oracle Cloud" (spec v0.3, secao 8.4).
# Nao contem nada do cliente nem segredo; a stack NAO gera chave (sem tls_private_key).

locals {
  ob     = jsondecode(base64decode(var.onboarding_code))
  parent = var.parent_compartment_ocid != "" ? var.parent_compartment_ocid : var.tenancy_ocid
  # Sufixo do onboarding: nomes de IAM sao unicos no tenancy e a OCI segura o nome de compartment apagado,
  # entao um segundo onboarding (ou um refeito apos apagar o anterior) nao pode repetir nomes fixos.
  sfx    = substr(replace(local.ob.onboarding_id, "-", ""), 0, 8)
  name   = "bc-migration-${local.sfx}"
  group  = "${local.name}-group"
  bucket = local.name
}

data "oci_objectstorage_namespace" "ns" { compartment_id = var.tenancy_ocid }

resource "oci_identity_compartment" "bc" {
  compartment_id = local.parent
  name           = local.name
  description    = "Migracao Binario Cloud (temporario)"
  enable_delete  = true
}

resource "oci_objectstorage_bucket" "bc" {
  compartment_id = oci_identity_compartment.bc.id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = local.bucket
  access_type    = "NoPublicAccess"
}

resource "oci_identity_group" "bc" {
  compartment_id = var.tenancy_ocid
  name           = local.group
  description    = "Binario Cloud migration"
}

resource "oci_identity_user" "bc" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name}-svc"
  description    = "Usuario de servico Binario Cloud (somente API key)"
  email          = var.service_user_email != "" ? var.service_user_email : null
}

resource "oci_identity_user_capabilities_management" "bc" {
  user_id                      = oci_identity_user.bc.id
  can_use_api_keys             = true
  can_use_console_password     = false
  can_use_auth_tokens          = false
  can_use_customer_secret_keys = false
  can_use_smtp_credentials     = false
}

resource "oci_identity_api_key" "bc" {
  user_id   = oci_identity_user.bc.id
  key_value = local.ob.bc_public_key_pem # chave PUBLICA da BC (S6)
}

resource "oci_identity_user_group_membership" "bc" {
  user_id  = oci_identity_user.bc.id
  group_id = oci_identity_group.bc.id
}

resource "oci_identity_policy" "bc" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name}-policy"
  description    = "Menor privilegio para migracao Binario Cloud"
  statements = [
    "Allow group ${local.group} to read instances in compartment id ${var.source_compartment_ocid}",
    "Allow group ${local.group} to use instances in compartment id ${var.source_compartment_ocid}",
    "Allow group ${local.group} to manage instance-images in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to read buckets in compartment id ${oci_identity_compartment.bc.id} where target.bucket.name='${local.bucket}'",
    "Allow group ${local.group} to manage objects in compartment id ${oci_identity_compartment.bc.id} where target.bucket.name='${local.bucket}'",
    "Allow group ${local.group} to manage buckets in compartment id ${oci_identity_compartment.bc.id} where all {target.bucket.name='${local.bucket}', request.permission='PAR_MANAGE'}",
  ]
}

# H2 (PROVISORIA, desligado por padrao): POST dos mesmos dados nao secretos do handoff_code.
data "http" "callback" {
  count           = var.enable_callback ? 1 : 0
  url             = var.callback_url
  method          = "POST"
  request_headers = { "Content-Type" = "application/json" }
  request_body    = jsonencode(local.handoff)

  depends_on = [
    oci_identity_api_key.bc,
    oci_identity_policy.bc,
    oci_identity_user_group_membership.bc,
    oci_identity_user_capabilities_management.bc,
  ]
}
