# Lab 07 - Cloud NAT for the private VM

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed, tested and destroyed on 2026-11-21 (the NAT was up for about 2 minutes). The code stays ready to turn on again when the VM needs updates.

The [Lab 02](../02-secure-compute-engine/README.md) VM has no public IP. IAP gives me an **inbound** path to manage it, but it gives the VM no **outbound** path: with no route to the internet, it cannot even run `apt update`. This lab adds that outbound path with Cloud NAT, without giving the VM a public IP and without opening any inbound port.

## How it works

```text
lab02-secure-vm (10.20.0.2, no public IP)
   │  outbound connection (for example, apt update)
   ▼
Cloud Router "lab07-nat-router" + Cloud NAT "lab07-nat"  (us-central1)
   │  swaps the internal IP for a Google-managed external IP
   ▼
Internet  ── replies come back through the same translation; nobody can open a connection from outside
```

## What gets created

| Resource | Detail |
| --- | --- |
| Cloud Router `lab07-nat-router` | In `us-central1`, on `portfolio-vpc`. No BGP: it only hosts the NAT config |
| Cloud NAT `lab07-nat` | Automatic external IP (`AUTO_ONLY`), only for the `lab02-iowa-subnet` subnet, logging errors only |

The VPC and subnet are read with data sources. This lab never touches the Lab 01 or Lab 02 state.

## Decisions I made

- **Only the subnet that needs it.** `LIST_OF_SUBNETWORKS` instead of "every subnet in the region". If another subnet is created in Iowa, it does not get internet access by accident.
- **Automatic IP, not reserved.** With `AUTO_ONLY`, Google manages the IP and it goes away with the NAT on `destroy`. A reserved IP that gets forgotten keeps being billed.
- **Errors-only logging.** `ERRORS_ONLY` records things like port exhaustion, which is what helps troubleshooting, with minimal log volume.
- **Outbound is not inbound.** NAT only translates connections the VM starts. The Lab 02 inbound firewall stays the same: SSH through IAP only.
- **On only when needed.** NAT is billed by the hour while it exists (see Cost). Since everything is in Terraform, create, use and destroy are three commands.

## Checkov

No findings. Checkov 3.4.6 has no checks for Cloud Router and Cloud NAT, and the scan of all labs still has 0 failures (72 passed, 9 accepted with a reason in the other labs).

## How to run

You need `roles/compute.networkAdmin` (or project owner) to create the Cloud Router and NAT.

```powershell
cd projects/07-cloud-nat
Copy-Item terraform.tfvars.example terraform.tfvars   # set project_id
terraform init -lockfile=readonly
terraform plan
terraform apply
```

## How to test

Before `apply`, the VM cannot reach the internet:

```powershell
gcloud compute ssh lab02-secure-vm --zone=us-central1-a --tunnel-through-iap --command="curl -sS -m 10 -o /dev/null -w '%{http_code}' https://deb.debian.org/"
# curl: (28) Connection timed out ... -> 000
```

After `apply`, the same command should return `200`, and `sudo apt-get update` should work.

## Cost

Cloud NAT is billed while it exists, even when idle:

- an hourly gateway fee for each VM using the NAT;
- the external IP used by the NAT, billed by the hour;
- each GB processed by the NAT.

For one VM, that adds up to a few dollars a month if the NAT stays on all month. With my goal of spending under US$ 10 a month, the plan is to turn NAT on only to update the VM and then run `terraform destroy`. Check current prices on the [Cloud NAT](https://cloud.google.com/nat/pricing) and [IP address](https://cloud.google.com/vpc/network-pricing#ipaddress) pricing pages. The [Lab 04](../04-monitoring-alerts/README.md) budget warns if anything grows.

## Cleanup

```powershell
terraform destroy
```

Since the IP is automatic, nothing is left behind.

## Checklist

- [x] Terraform written (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt`, `validate` and Checkov passing locally
- [x] Baseline recorded: without NAT, the VM cannot reach the internet (`curl` timeout, 2026-11-21)
- [x] Deployed and outbound access tested from the VM on 2026-11-21: `curl` 200, `apt-get update` fetched 2.4 MB, Google-managed egress IP; 2 upgradable packages, none from security
- [x] Destroyed after the test: no Cloud Router or IP left, and the VM went back to timing out (`curl` 000)
