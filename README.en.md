# Google Cloud Portfolio

Google Cloud labs built with Terraform on my own project: each one deployed, tested and documented with what I did and why.

[Português](README.md) | [English](README.en.md)

[![Terraform CI](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml)

## In 30 seconds

- **7 Terraform labs**: network, private VM, remote state, monitoring, Cloud Run, keyless CI and Cloud NAT.
- **Actually deployed** and tested, with the date and test result in each lab's README.
- **Secure by default**: no VM with a public IP, no service account keys, access only through IAP.
- **Cost under control**: a budget with alerts, and expensive resources only exist while I test them.
- **Automatic review** on every pull request: validation, security scan (Checkov) and `terraform plan`.

The lab write-ups are in Brazilian Portuguese; the code and its comments are in English.

## Labs

| # | Lab | What it solves | Status |
| --- | --- | --- | --- |
| 01 | [VPC network](projects/01-vpc-network/README.md) | Custom-mode VPC with a planned subnet | Deployed |
| 02 | [Private VM](projects/02-secure-compute-engine/README.md) | VM with no public IP, reachable only through IAP with OS Login | Deployed, access tested |
| 03 | [Terraform state](projects/03-terraform-backend/README.md) | Hardened bucket with versioning, locking and a recovery runbook | Deployed |
| 04 | [Monitoring and budget](projects/04-monitoring-alerts/README.md) | CPU, VM-down and IAM-change alerts; monthly budget | Deployed, alerts tested |
| 05 | [Cloud Run app](projects/05-cloud-run-app/README.md) | Private containerized API with a Secret Manager secret | Deployed, call tested |
| 06 | [Keyless CI](projects/06-workload-identity-federation/README.md) | GitHub Actions reaching Google Cloud with short-lived credentials | Deployed, used by CI |
| 07 | [Cloud NAT](projects/07-cloud-nat/README.md) | Outbound internet for the private VM, no inbound path | Tested and destroyed (on when needed) |

## About me

I have worked in IT since 2014: Windows Server, Active Directory, networking and, today, Tier 2 telecom and VoIP. My Microsoft infrastructure labs live in [microsoft-infra-labs](https://github.com/matheuslab-bit/microsoft-infra-labs).

[LinkedIn](https://linkedin.com/in/matheus-s-ti) · [matheus.silva.gcp@gmail.com](mailto:matheus.silva.gcp@gmail.com)
