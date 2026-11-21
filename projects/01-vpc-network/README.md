# Lab 01 - VPC network

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed in São Paulo (`southamerica-east1`). Terraform state moved to Cloud Storage (`labs/01-vpc-network`) on 2026-11-20.

The base network for the other labs: a custom-mode VPC with one regional subnet. Its state is stored in the bucket from [Lab 03](../03-terraform-backend/README.md).

## What it creates

- **VPC `portfolio-vpc`** with `auto_create_subnetworks = false` and `routing_mode = "REGIONAL"`.
- **Subnet `portfolio-subnet`**, `10.10.0.0/24`, in São Paulo.
- **Remote state** (`backend.tf`) in the bucket `gcp-portfolio-tfstate-usc1-7f4e9a2c` (`us-central1`), prefix `labs/01-vpc-network`, with versioning, 7-day Soft Delete and locking.

I turned off automatic subnets on purpose. In auto mode Google creates a subnet in every region with ranges it picks. In custom mode, every range in the network is one I planned.

[Lab 02](../02-secure-compute-engine/README.md) reuses this VPC: it reads it through a data source and adds its own subnet in Iowa.

## Inputs and outputs

| Variable | What it is | Default |
| --- | --- | --- |
| `project_id` | Google Cloud project ID | required |
| `region` | Subnet region | `southamerica-east1` |
| `network_name` | VPC name | `portfolio-vpc` |
| `subnet_name` | Subnet name | `portfolio-subnet` |
| `subnet_cidr` | Subnet range | `10.10.0.0/24` |

Outputs: `vpc_name`, `vpc_id`, `subnet_name`, `subnet_cidr` and `subnet_region`.

`project_id` must be a valid project ID and `subnet_cidr` must be a valid IPv4 range, otherwise Terraform stops before calling the API. Versions are in [`versions.tf`](versions.tf): Google provider `7.46.2`, the same as in `.terraform.lock.hcl`.

## What I verified

- `portfolio-vpc` and `portfolio-subnet` are deployed and active.
- `backend.tf` was added in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10). On 2026-11-20 I moved the state from my disk to `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c/labs/01-vpc-network/default.tfstate` with `terraform init -migrate-state`. After that, `terraform state list`, `terraform plan` (`No changes. Your infrastructure matches the configuration.`) and `gcloud compute` showed no drift, and object versioning was on.
- Locally, `terraform fmt -check -recursive`, `terraform validate` and `terraform plan` passed with Terraform `1.17.2`.
- In GitHub Actions, [`terraform-ci.yml`](../../.github/workflows/terraform-ci.yml) validates the lab with Terraform `1.9.8` (the oldest version I support) and runs Checkov. CI uses `-backend=false`, so it needs no cloud credentials.

## Checkov findings I accepted

Each one is explained in a `#checkov:skip` comment in [`main.tf`](main.tf):

| Check | Why |
| --- | --- |
| `CKV_GCP_26`, VPC Flow Logs | Left for the monitoring lab, to avoid log costs for now. |
| `CKV_GCP_74`, Private Google Access | Nothing runs in the São Paulo subnet yet. I will turn it on when a workload needs Google APIs. |
| `CKV2_GCP_18`, network firewall | Firewall rules belong to each workload lab. Lab 02 has its own IAP allow/deny rules. |

## How to run

You need Terraform `>= 1.9.8, < 2.0.0`, a project with billing and the Compute Engine API on, access to the state bucket (`roles/storage.objectAdmin` on the bucket), permission to manage VPCs and the `gcloud` CLI.

Check the code without any credentials, from `projects/01-vpc-network/`:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

Against the real backend:

```powershell
gcloud auth application-default login
terraform init -lockfile=readonly
terraform plan
```

`project_id` goes in a local `terraform.tfvars` that is not committed (or `-var="project_id=YOUR_PROJECT_ID"`). Never put credentials in Terraform files.

## Cost and cautions

A VPC and subnets with no external IPs, Cloud NAT or VPN have no fixed hourly cost. Network egress and whatever runs inside can cost money.

Lab 02 depends on `portfolio-vpc`, so **do not run `terraform destroy` here** while Lab 02 exists. Keep `.terraform/`, local state backups, saved plans, credentials and `*.tfvars` out of Git.

## Checklist

- [x] Terraform files written and documented (`versions.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt -check` and `terraform validate` passed locally
- [x] CI passed in GitHub Actions (`push` and `pull_request`)
- [x] Deployed in São Paulo (`portfolio-vpc` and `portfolio-subnet`, `10.10.0.0/24`), checked with `gcloud compute` and `terraform plan` (`No changes`)
- [x] `backend.tf` added ([PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10)) and state moved to GCS (`labs/01-vpc-network`) with locking and versioning checked
