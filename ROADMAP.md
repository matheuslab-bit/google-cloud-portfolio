# Roadmap

[English](ROADMAP.md) | [Português (Brasil)](ROADMAP.pt-BR.md)

My study plan for Google Cloud. It is a plan, not a list of things I already master. I only tick an item when there is something published to back it up (a lab README, a pull request or a CI run).

## Progress

- [ ] Cloud and networking foundations
- [ ] Linux fundamentals lab
- [x] First GCP project with billing safeguards (budget and alerts deployed and tested in [Lab 04](projects/04-monitoring-alerts/README.md))
- [x] Compute Engine and VPC: [Lab 01](projects/01-vpc-network/README.md) and [Lab 02](projects/02-secure-compute-engine/README.md)
- [ ] IAM and security lab (partly covered by Lab 02: dedicated service account, IAP, OS Login)
- [ ] App deployed on Cloud Run (code ready in [Lab 05](projects/05-cloud-run-app/README.md))
- [ ] Monitoring and logging lab (code ready in [Lab 04](projects/04-monitoring-alerts/README.md))
- [x] Terraform project: labs 01 to 03 with remote state in GCS
- [x] Three documented portfolio projects: [project index](projects/README.md)
- [ ] Associate Cloud Engineer exam preparation

## Log

- **2026-11-18:** Lab 01 (VPC) and Lab 02 (private VM with IAP and OS Login) merged with CI passing. Lab 02 deployed in Iowa and SSH access tested.
- **2026-11-20:** Lab 03 (GCS remote state) deployed. Lab 01 and Lab 02 state moved to GCS, with `terraform plan` showing no changes.
- **2026-11-20:** CI merged into a single Terraform workflow with a Checkov scan. Accepted risks written next to each resource.
- **2026-11-21:** Labs 04 (monitoring and budget), 05 (Cloud Run) and 06 (Workload Identity Federation) written and validated in CI. Audit and cost scripts tested on this project; the audit found SSH and RDP open on the `default` network and Editor on the default compute service account.
- **2026-11-21:** Audit findings fixed (backup first, then the two `default` rules deleted and Editor removed from the default compute service account). The audit now returns 0 alerts.
- **2026-11-21:** Lab 04 deployed: e-mail channel, three alerts (CPU, VM silent, IAM change) and a R$ 50 monthly budget that subtracts Free Tier but not promotional credits, to keep spending under US$ 10 a month. Enabling the Cloud Resource Manager API was a missing prerequisite (now in the lab README).

## Next

1. Deploy Lab 06 and turn on keyless `terraform plan` in pull requests.
2. Deploy labs 04 and 05 and tick their checklists.
3. Cloud NAT for the private VM, then Cloud SQL with private access.

## What I still want to study

**Google Cloud core:** organizations, folders and projects; IAM and service accounts; Compute Engine and Cloud Storage; VPC, routes and firewall; Cloud DNS, Cloud SQL and Cloud Run; load balancing.

**Operations and security:** Cloud Logging and Monitoring; alerts and audit logs; Secret Manager and Cloud KMS; backup and recovery.

**Automation:** Terraform modules; Docker; Kubernetes and GKE basics; Cloud Build, Artifact Registry and GitHub Actions; Bash and Python.

**Certification:** Associate Cloud Engineer, with practice labs and reviewing my weak spots.

My routine is about 10 hours a week, split between studying, guided labs, rebuilding things on my own and writing the documentation.
