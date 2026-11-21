# Lab 02 - Private VM in Iowa

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed in Iowa (`us-central1-a`). SSH through IAP and OS Login tested on 2026-11-18. Terraform state moved to Cloud Storage (`labs/02-secure-compute-engine`) on 2026-11-20.

A Debian 12 `e2-micro` VM with no public IP. The only way in is SSH through Identity-Aware Proxy (IAP) with OS Login, which uses IAM instead of SSH keys. The Iowa setup was merged in [PR #4](https://github.com/matheuslab-bit/matheuslab-bit/pull/4) after CI passed. After the merge I deployed it, tested the access and later moved the state to the [Lab 03](../03-terraform-backend/README.md) bucket, with `backend.tf` added in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

This is a lab, not a production service, and not a promise of zero cost.

## What belongs to whom

| Resource | Setup | Managed by |
| --- | --- | --- |
| VPC | `portfolio-vpc`, read with `data "google_compute_network"` | Lab 01 (untouched) |
| São Paulo subnet | `portfolio-subnet`, `southamerica-east1`, `10.10.0.0/24` | Lab 01 (untouched) |
| Iowa subnet | `lab02-iowa-subnet`, `us-central1`, `10.20.0.0/24`, `IPV4_ONLY` | Lab 02 |
| VM | `lab02-secure-vm`, `us-central1-a`, `e2-micro`, `STANDARD` | Lab 02 |
| Boot disk | 10 GB `pd-standard`, `debian-cloud/debian-12`, `auto_delete = true` | Lab 02 |
| Service account | `lab02-secure-vm`, with no roles and no keys | Lab 02 |
| SSH firewall | Allow IAP (`35.235.240.0/20`) at priority `900`, deny any other IPv4 (`0.0.0.0/0`) at `901` | Lab 02 |
| Remote state | `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c`, prefix `labs/02-secure-compute-engine` | Lab 03 bucket |

A VPC in Google Cloud is global. Adding a subnet in Iowa does not change the São Paulo subnet. Lab 02 has its own subnet and its own state prefix, and never touches Lab 01's state.

```text
Me -> IAP -> TCP 22 from 35.235.240.0/20 (priority 900) -> lab02-secure-vm
                Anything else on port 22 (priority 901)   -> blocked
```

## Security choices

- **No public IP:** the network interface has no `access_config` block, and `stack_type = "IPV4_ONLY"`.
- **SSH only from IAP, with an explicit deny right after:** port 22 is allowed only from `35.235.240.0/20` (the IAP range) at priority `900`, and then denied for everyone else at `901`. Both numbers are lower than the common priority-1000 rules, so they win. The rules only apply to this VM's service account, so that account should not be reused on other VMs.
- **Firewall before the VM:** the VM has `depends_on` for both rules, so the SSH rules exist before the machine is created.
- **OS Login and locked metadata:** `enable-oslogin = "TRUE"`, `block-project-ssh-keys = "TRUE"` and `serial-port-enable = "FALSE"`.
- **Shielded VM:** Secure Boot, vTPM and integrity monitoring on.
- **Service account with nothing:** no keys and no project roles. The `cloud-platform` OAuth scope alone does not grant IAM permissions.
- **Project ID out of the code:** `project_id` is required, checked with a regex and set in a local `terraform.tfvars` (copied from `terraform.tfvars.example`, ignored by Git).
- **Small network scope:** no Cloud NAT, proxy, startup script or package installation. Private Google Access is `false` only on the Iowa subnet.

IAP gives me a way in to manage the VM. It does not give the VM a way out to the internet. Updating Debian packages would need an outbound path that I have not built yet. Also, the `debian-12` image family can point to newer builds in future plans. Without patching, egress and monitoring, this VM is not a production server.

## Checkov

Checkov runs on this lab through [`terraform-ci.yml`](../../.github/workflows/terraform-ci.yml): **22 checks pass**, including no public IP, no default service account, OS Login, blocked project SSH keys, serial port off, Shielded VM and no SSH or RDP open to the world. The findings I accepted are explained with `#checkov:skip` in [`main.tf`](main.tf):

| Check | Why |
| --- | --- |
| `CKV_GCP_26`, VPC Flow Logs | Left for the monitoring lab, to avoid log costs for now. |
| `CKV_GCP_74`, Private Google Access | Off on purpose. The VM has no approved outbound path in this lab. |
| `CKV_GCP_38`, disk encryption with my own keys | The disk uses Google-managed encryption. Customer-managed keys are planned for a Cloud KMS lab. |

## Permissions

The project needs billing on, `e2-micro` and standard disk available in `us-central1`, the `portfolio-vpc` network, the Lab 03 bucket, and the Compute Engine, IAM, IAP and OS Login APIs enabled.

Whoever runs Terraform needs read/write on the state bucket (`roles/storage.objectAdmin` on the bucket, for the state and the `.tflock`), read access to the VPC and public images, and permission to manage the Iowa subnet, the VM and disk, the firewall rules and the service account, including `iam.serviceAccounts.actAs` on the VM's service account.

To connect over SSH, the person needs `roles/iap.tunnelResourceAccessor`, `roles/compute.osLogin` (or `roles/compute.osAdminLogin` for sudo), permission to see the instance and `roles/iam.serviceAccountUser` on the VM's service account.

## How to run

Always from `projects/02-secure-compute-engine/`. Terraform `>= 1.9.8, < 2.0.0` (CI uses `1.9.8`). Google provider `7.46.2`, pinned in `.terraform.lock.hcl`.

Check the code without credentials (same as CI):

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

Against the real backend:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# put the real project_id in terraform.tfvars
terraform init -lockfile=readonly -input=false
terraform plan -input=false
```

Connect through IAP:

```powershell
gcloud compute ssh lab02-secure-vm --project=YOUR_PROJECT_ID --zone=us-central1-a --tunnel-through-iap
```

In the 2026-11-18 test, SSH through IAP and OS Login worked, and I confirmed there was no external IP, the 10 GB `pd-standard` disk, the three Shielded VM protections and the link to `lab02-iowa-subnet`. After moving the state on 2026-11-20, `terraform plan` showed `No changes. Your infrastructure matches the configuration.`

## Cost (Free Tier)

The Google Cloud Free Tier includes, per month, the equivalent of one non-preemptible `e2-micro` in some US regions (`us-central1`, `us-west1` or `us-east1`) and up to 30 GB-month of `pd-standard`, following Google's current billing terms. This lab uses one `e2-micro` in `us-central1-a` and a 10 GB `pd-standard` disk, with no public IPv4, Cloud NAT, snapshots, load balancers or paid OS images.

- Being eligible for the Free Tier does not mean zero cost.
- The free quota is shared across the whole billing account. Other projects in the same month can use it up.
- Egress, taxes and other APIs or logs can still be charged.
- Budget alerts do not stop spending or turn anything off. Set up budgets and watch the real usage.

## State and cleanup

- State lives in `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c/labs/02-secure-compute-engine/default.tfstate` (`backend.tf`), with versioning, a 90-day rule for old versions, 7-day Soft Delete and `.tflock` locking.
- Keep `.terraform/`, state backups (`*.tfstate*`), saved plans (`*.tfplan`), `*.tfvars`, credentials, private keys and logs out of Git.
- Never run `terraform destroy` on Lab 01 to clean up Lab 02.

## History

- [PR #2](https://github.com/matheuslab-bit/matheuslab-bit/pull/2) and [PR #3](https://github.com/matheuslab-bit/matheuslab-bit/pull/3): separate Lab 02 structure, firewall order `900`/`901` and the VM depending on both rules.
- [PR #4](https://github.com/matheuslab-bit/matheuslab-bit/pull/4): moved Lab 02 to `us-central1` (Iowa) with its own subnet (`10.20.0.0/24`), merged after CI passed.
- 2026-11-18: deployed in Iowa and tested SSH through IAP and OS Login.
- 2026-11-20: moved the state to the GCS bucket (`labs/02-secure-compute-engine`) with `terraform init -migrate-state`, no changes in the plan, and `backend.tf` added in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

## References

- [Google Cloud Free Tier](https://docs.cloud.google.com/free/docs/free-cloud-features)
- [Compute Engine pricing](https://cloud.google.com/products/compute/pricing/general-purpose)
- [Disk and image pricing](https://cloud.google.com/compute/disks-image-pricing)
- [IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding)
- [OS Login setup](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin)
- [Service accounts and `actAs`](https://docs.cloud.google.com/iam/docs/service-accounts-actas)
- [VPC firewall rules and priorities](https://docs.cloud.google.com/firewall/docs/firewalls)
