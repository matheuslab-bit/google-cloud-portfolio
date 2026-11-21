# Google Cloud Portfolio

My Google Cloud labs, built with Terraform and deployed to my own project.

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

[![Terraform CI](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml)

I am an infrastructure analyst. I have worked in IT since 2014, with Windows Server, Active Directory, Hyper-V and Tier 2 support for telecom and VoIP. This repository is where I learn Google Cloud by building small, real pieces, deploying them and writing down what I did and why.

It is a learning portfolio, not production cloud experience.

My on-premises Microsoft labs are in [microsoft-infra-labs](https://github.com/matheuslab-bit/microsoft-infra-labs). Profile: [github.com/matheuslab-bit](https://github.com/matheuslab-bit).

## Labs

1. [VPC network](projects/01-vpc-network/README.md): a custom-mode VPC with one subnet in São Paulo. Deployed.
2. [Private VM](projects/02-secure-compute-engine/README.md): a Debian VM in Iowa with no public IP. SSH only through IAP and OS Login. Deployed, and access tested on 2026-11-18.
3. [Terraform state bucket](projects/03-terraform-backend/README.md): a locked-down Cloud Storage bucket that holds the Terraform state of labs 1 and 2. Deployed on 2026-11-20.

## How the pieces fit

```text
Lab 03: state bucket (us-central1)  <-- remote state of Lab 01 and Lab 02

Lab 01: portfolio-vpc (global, custom mode)
  ├── portfolio-subnet    southamerica-east1   10.10.0.0/24
  └── lab02-iowa-subnet   us-central1          10.20.0.0/24   (owned by Lab 02)
        └── lab02-secure-vm   e2-micro, no external IP

Me -> IAP (35.235.240.0/20) -> TCP 22 (firewall priority 900) -> VM
```

- Lab 01 owns the VPC and the São Paulo subnet.
- Lab 02 reads the VPC through a data source and owns only its subnet, firewall rules, service account and VM.
- Lab 03 is the starting point: its own state stays local, and it stores the state of labs 1 and 2 under separate prefixes (`labs/01-vpc-network` and `labs/02-secure-compute-engine`).
- I picked Iowa (`us-central1`) because it can fall under the Free Tier. That is not a guarantee of zero cost.

## How I work in this repo

- Every resource is in Terraform. The Google provider is pinned to `7.46.2` and the lock files are committed.
- Inputs like project ID, CIDR ranges and bucket name are validated before any API call.
- State lives in a versioned GCS bucket with locking, one prefix per lab.
- GitHub Actions runs `terraform fmt`, `init -backend=false` and `validate` for each lab, plus a Checkov security scan. CI has no cloud credentials.
- When I accept a Checkov finding, I write the reason in a `#checkov:skip` comment right next to the resource.
- No public IPs, SSH only through IAP, OS Login, Shielded VM and service accounts without keys or project roles.
- Each lab README says what is planned, what passed validation and what is really deployed, with dates and pull requests.

## Repository layout

```text
.
├── .github/workflows/terraform-ci.yml   # validation per lab + Checkov
├── projects/
│   ├── 01-vpc-network/
│   ├── 02-secure-compute-engine/
│   ├── 03-terraform-backend/
│   └── archive/                         # my first prototype, kept for reference
└── ROADMAP.md / ROADMAP.pt-BR.md        # what I am studying next
```

## Next steps

- Workload Identity Federation, so GitHub Actions can run `terraform plan` without keys
- A monitoring and logging lab (Cloud Monitoring, Cloud Logging, VPC Flow Logs, budget alerts)
- An app on Cloud Run with Artifact Registry and Secret Manager
- The Associate Cloud Engineer (ACE) certification

Full plan in the [roadmap](ROADMAP.md).

## Contact

[LinkedIn](https://linkedin.com/in/matheus-s-ti) · [matheus.silva.gcp@gmail.com](mailto:matheus.silva.gcp@gmail.com)

---

These are learning exercises, not production hosting.
