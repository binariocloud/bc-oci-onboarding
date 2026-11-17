# bc-oci-onboarding

Terraform stack for the **Deploy to Oracle Cloud** button used by Binario Cloud to migrate VMs from OCI to BCP.

It creates, in the customer's tenancy, a compartment, a private bucket, a service user (API key only), a group and a least-privilege policy, all named `bc-migration-<onboarding id>`. Since 1.0.2 it also creates a private network for the temporary helper VM that copies the disks (VCN, private subnet with no public IPs, service gateway to Oracle Services only; no internet or NAT gateway). Since 1.1.0, unless `p2p_egress = "none"`, it adds a public subnet with an internet gateway to the same VCN for the direct disk copy engine: no ingress rules, egress only TCP 22 to Binario Cloud floating IP ranges (`bcp_fip_cidrs`) and 443 to Oracle Services, plus `manage public-ips` in the BC compartment for the helper's ephemeral public IP. The package holds no customer data and no secrets: it never generates a private key. It only registers the public key that comes in the `onboarding_code` issued by Binario Cloud.

Packages are published as release assets: `bc-oci-onboarding-vX.Y.Z.zip`.
