# bc-oci-onboarding

Terraform stack for the **Deploy to Oracle Cloud** button used by Binario Cloud to migrate VMs from OCI to BCP.

It creates, in the customer's tenancy, a compartment, a private bucket, a service user (API key only), a group and a least-privilege policy, all named `bc-migration-<onboarding id>`. The package holds no customer data and no secrets: it never generates a private key. It only registers the public key that comes in the `onboarding_code` issued by Binario Cloud.

Packages are published as release assets: `bc-oci-onboarding-vX.Y.Z.zip`.
