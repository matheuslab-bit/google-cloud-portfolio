# Google Cloud Portfolio

My Google Cloud labs, built with Terraform in my own project, plus the scripts and notes I keep along the way.

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

[![Terraform CI](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml)

I am an infrastructure analyst. I have worked in IT since 2014, with Windows Server, Active Directory, Hyper-V and Tier 2 support for telecom and VoIP. This repository is where I learn Google Cloud by building small, real pieces, deploying them and writing down what I did and why.

It is a learning portfolio, not production cloud experience. Each lab says clearly what is deployed and what is only validated code.

My on-premises Microsoft labs are in [microsoft-infra-labs](https://github.com/matheuslab-bit/microsoft-infra-labs). Profile: [github.com/matheuslab-bit](https://github.com/matheuslab-bit).

## What is inside

```text
projects/   6 Terraform labs, all deployed
scripts/    gcloud scripts to audit security and find forgotten costs
dicas/      tips: gcloud, Terraform, security, costs, common errors, ACE study (Portuguese)
```

## Labs

| # | Lab | What it shows | Status |
| --- | --- | --- | --- |
| 01 | [VPC network](projects/01-vpc-network/README.md) | Custom-mode VPC with a planned subnet in São Paulo | **Deployed** |
| 02 | [Private VM](projects/02-secure-compute-engine/README.md) | Debian VM with no public IP, SSH only through IAP and OS Login, Shielded VM, firewall ordering | **Deployed**, access tested on 2026-11-18 |
| 03 | [Terraform state bucket](projects/03-terraform-backend/README.md) | Locked-down GCS backend with versioning, Soft Delete, locking and a recovery procedure | **Deployed** on 2026-11-20, holds the state of labs 01 and 02 |
| 04 | [Monitoring and budget](projects/04-monitoring-alerts/README.md) | Alerts for CPU, VM down and IAM changes; monthly budget with a forecast alert | **Deployed** on 2026-11-21, alerts tested |
| 05 | [App on Cloud Run](projects/05-cloud-run-app/README.md) | Container in Artifact Registry, private Cloud Run service, secret read from Secret Manager | **Deployed** on 2026-11-21, called with an identity token |
| 06 | [Workload Identity Federation](projects/06-workload-identity-federation/README.md) | GitHub Actions reaching Google Cloud with no stored key, with a pinned trust condition | **Deployed** on 2026-11-21 |

## How the deployed labs fit

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
- Labs 04 to 06 are independent and will use the same bucket, each under its own prefix.
- I picked Iowa (`us-central1`) because it can fall under the Free Tier. That is not a guarantee of zero cost.

## Scripts

[Two read-only `gcloud` scripts](scripts/README.md):

- `auditoria-seguranca.sh` looks for public VMs, firewall rules open to the internet, user-managed service account keys, public buckets, basic roles on service accounts and VMs using the default service account.
- `custos-recursos.sh` lists what keeps billing without anyone using it: detached disks, idle static IPs, stopped VMs and old snapshots.

When I ran the audit on this project, it found three default settings Google creates on its own (SSH and RDP open on the `default` network, and Editor on the default compute service account). I fixed all three on 2026-11-21, and the audit now returns 0 alerts. The story and the fix are in [`dicas/seguranca.md`](dicas/seguranca.md).

## How I work in this repo

- Every resource is in Terraform. The Google provider is pinned to `7.46.2` and the lock files are committed.
- Inputs like project ID, CIDR ranges, e-mail and billing account are validated before any API call.
- State lives in a versioned GCS bucket with locking, one prefix per lab.
- GitHub Actions runs `terraform fmt`, `init -backend=false` and `validate` for each lab, a Checkov scan, the Cloud Run app tests and ShellCheck on the scripts. Pull requests that touch `projects/` also run a keyless `terraform plan` for labs 01 and 02 (Lab 06).
- When I accept a Checkov finding, I write the reason in a `#checkov:skip` comment next to the resource. When Checkov is right, I fix the code: in Lab 06 it flagged the Viewer role, and I replaced it with narrow read-only roles.
- No public IPs, SSH only through IAP, OS Login, Shielded VM and service accounts without keys or project roles.

## Repository layout

```text
.
├── .github/workflows/terraform-ci.yml   # validation per lab, Checkov, app tests, ShellCheck
├── projects/
│   ├── 01-vpc-network/
│   ├── 02-secure-compute-engine/
│   ├── 03-terraform-backend/
│   ├── 04-monitoring-alerts/
│   ├── 05-cloud-run-app/                 # Terraform + app/ (Node.js, Dockerfile, tests)
│   ├── 06-workload-identity-federation/  # Terraform + examples/ (keyless workflow)
│   └── archive/                          # my first prototype, kept for reference
├── scripts/                              # gcloud audit and cost scripts
├── dicas/                                # tips (Portuguese)
└── ROADMAP.md / ROADMAP.pt-BR.md
```

## Next steps

- Cloud NAT so the private VM can get updates without a public IP
- Cloud SQL with private access for the Cloud Run app
- The Associate Cloud Engineer (ACE) certification

Full plan in the [roadmap](ROADMAP.md).

## Contact

[LinkedIn](https://linkedin.com/in/matheus-s-ti) · [matheus.silva.gcp@gmail.com](mailto:matheus.silva.gcp@gmail.com)

---

These are learning exercises, not production hosting.
