locals {
  handoff = {
    v                       = 1
    onboarding_id           = local.ob.onboarding_id
    package_version         = local.ob.package_version
    tenancy_ocid            = var.tenancy_ocid
    region                  = var.region
    source_compartment_ocid = var.source_compartment_ocid
    bc_compartment_ocid     = oci_identity_compartment.bc.id
    bucket_namespace        = data.oci_objectstorage_namespace.ns.namespace
    bucket_name             = oci_objectstorage_bucket.bc.name
    group_ocid              = oci_identity_group.bc.id
    policy_ocid             = oci_identity_policy.bc.id
    service_user_ocid       = oci_identity_user.bc.id
    api_key_fingerprint     = oci_identity_api_key.bc.fingerprint
    helper_subnet_ocid      = oci_core_subnet.helper.id
  }
}

output "handoff_code" { value = base64encode(jsonencode(local.handoff)) }
output "service_user_ocid" { value = oci_identity_user.bc.id }
output "api_key_fingerprint" { value = oci_identity_api_key.bc.fingerprint }
output "helper_subnet_ocid" { value = oci_core_subnet.helper.id }
