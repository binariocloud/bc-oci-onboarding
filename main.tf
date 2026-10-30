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
  email          = var.service_user_email
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

# Statements CANDIDATOS da spec multi-disco §5.1, ainda pendentes da validação real na OCI (Task 0): a lista
# final pode encolher/mudar depois dela. Regra fixa: no compartment de ORIGEM só read/use (o usuário de serviço
# nunca apaga VM, volume ou imagem do cliente); manage só no compartment bc-migration-<id>.
# Sai "manage instance-images": a 0.8.0 não usa mais custom image (export por VM auxiliar).
resource "oci_identity_policy" "bc" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name}-policy"
  description    = "Menor privilegio para migracao Binario Cloud"
  statements = [
    # origem: inventário (VM, imagem base, anexos de disco, volumes) e SOFTSTOP/START do modo consistent
    "Allow group ${local.group} to read instance-family in compartment id ${var.source_compartment_ocid}",
    "Allow group ${local.group} to use instances in compartment id ${var.source_compartment_ocid}",
    "Allow group ${local.group} to read volume-family in compartment id ${var.source_compartment_ocid}",
    # origem: clonar os discos (volume group no compartment da BC com os volumes de origem; clone avulso)
    "Allow group ${local.group} to use volumes in compartment id ${var.source_compartment_ocid}",
    "Allow group ${local.group} to use boot-volumes in compartment id ${var.source_compartment_ocid}",
    # compartment da BC: volume groups, clones, VM auxiliar e seus anexos, rede da auxiliar
    "Allow group ${local.group} to manage volume-groups in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to manage volumes in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to manage boot-volumes in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to manage instances in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to manage volume-attachments in compartment id ${oci_identity_compartment.bc.id}",
    "Allow group ${local.group} to use virtual-network-family in compartment id ${oci_identity_compartment.bc.id}",
    # imagem de plataforma da VM auxiliar
    "Allow group ${local.group} to read instance-images in tenancy",
    # bucket da migração (inalterado desde 1.0.1)
    "Allow group ${local.group} to read buckets in compartment id ${oci_identity_compartment.bc.id} where target.bucket.name='${local.bucket}'",
    "Allow group ${local.group} to manage objects in compartment id ${oci_identity_compartment.bc.id} where target.bucket.name='${local.bucket}'",
    "Allow group ${local.group} to manage buckets in compartment id ${oci_identity_compartment.bc.id} where all {target.bucket.name='${local.bucket}', request.permission='PAR_MANAGE'}",
  ]
}

# Rede da VM auxiliar (1.0.2): VCN pequena e isolada no compartment da BC. Subnet privada, sem internet gateway
# nem NAT; a única saída é o service gateway para a Oracle Services Network (Object Storage, via PAR), porta 443.
data "oci_core_services" "osn" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  osn_service_id = data.oci_core_services.osn.services[0].id
  osn_cidr       = data.oci_core_services.osn.services[0].cidr_block
}

resource "oci_core_vcn" "helper" {
  compartment_id = oci_identity_compartment.bc.id
  display_name   = "${local.name}-vcn"
  cidr_blocks    = [var.helper_vcn_cidr]
}

resource "oci_core_service_gateway" "helper" {
  compartment_id = oci_identity_compartment.bc.id
  vcn_id         = oci_core_vcn.helper.id
  display_name   = "${local.name}-sgw"
  services {
    service_id = local.osn_service_id
  }
}

resource "oci_core_route_table" "helper" {
  compartment_id = oci_identity_compartment.bc.id
  vcn_id         = oci_core_vcn.helper.id
  display_name   = "${local.name}-rt"
  route_rules {
    destination       = local.osn_cidr
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.helper.id
  }
}

resource "oci_core_security_list" "helper" {
  compartment_id = oci_identity_compartment.bc.id
  vcn_id         = oci_core_vcn.helper.id
  display_name   = "${local.name}-sl"
  # sem regra de entrada: nada entra na auxiliar
  egress_security_rules {
    destination      = local.osn_cidr
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6" # TCP
    stateless        = false
    tcp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_subnet" "helper" {
  compartment_id             = oci_identity_compartment.bc.id
  vcn_id                     = oci_core_vcn.helper.id
  display_name               = "${local.name}-subnet"
  cidr_block                 = var.helper_vcn_cidr
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.helper.id
  security_list_ids          = [oci_core_security_list.helper.id]
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
