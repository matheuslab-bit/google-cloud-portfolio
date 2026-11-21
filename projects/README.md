# Projects

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

My Google Cloud labs. For each one I note separately what passed code validation, what is deployed and what I have tested.

## Labs

**[01: VPC network](01-vpc-network/README.md)**
Custom-mode VPC (`portfolio-vpc`) and one subnet (`10.10.0.0/24`) in São Paulo (`southamerica-east1`).
Deployed. CI passed in [PR #1](https://github.com/matheuslab-bit/matheuslab-bit/pull/1). State moved to GCS on 2026-11-20 with no changes in `terraform plan`, and `backend.tf` added in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

**[02: Private VM](02-secure-compute-engine/README.md)**
Debian 12 `e2-micro` in Iowa (`us-central1-a`) with its own subnet (`10.20.0.0/24`), SSH only through IAP, OS Login, Shielded VM and firewall rules at priority `900`/`901`.
Iowa setup merged in [PR #4](https://github.com/matheuslab-bit/matheuslab-bit/pull/4). Deployed and SSH through IAP tested on 2026-11-18. State moved to GCS on 2026-11-20 with no changes, `backend.tf` in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

**[03: Terraform state bucket](03-terraform-backend/README.md)**
Cloud Storage bucket in Iowa (`us-central1`) with object versioning, 7-day Soft Delete, a 90-day rule for old versions, uniform access, public access blocked and protection against deletion.
Deployed on 2026-11-20 ([PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9)). It holds the current state of labs 01 and 02.

## Notes

- Lab 02 reads the `portfolio-vpc` from Lab 01 through a data source and manages only its own Iowa subnet.
- Labs 01 and 02 store their state in the Lab 03 bucket, each under its own prefix, with locking. Lab 03 keeps its own state locally (plus a separate backup outside the repo), because a bucket cannot safely hold its own state.
- Cost: the `e2-micro` VM, the 10 GB `pd-standard` disk and the bucket (about 24 KB of state) fit inside the monthly Free Tier. Shared quotas, network egress and other services can still cost money.

## Archive

[GCP Secure Infrastructure (archived)](archive/gcp-secure-infrastructure/README.md): my first attempt, a single big Terraform setup with compute, security and monitoring. I replaced it with labs 01 to 03 and kept it for the monitoring ideas.

## Planned

- App on Cloud Run with Artifact Registry, Cloud SQL, Secret Manager and monitoring
- Workload Identity Federation (CI without keys) and reusable Terraform modules

Planned work stays out of the list above until it exists.

Never commit secrets, Terraform state or credentials. This is a learning portfolio, not a production service.
