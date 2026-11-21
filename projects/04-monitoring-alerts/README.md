# Lab 04 - Monitoring, alerts and budget

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** code written and validated in CI (fmt, validate, Checkov). Not deployed yet.

A VM nobody watches only gets attention when a user complains. This lab adds the alerts I would want on day one: the Lab 02 VM using too much CPU or going silent, a security alert when someone changes IAM permissions, and a monthly budget that warns me before the bill surprises me.

## What it creates

| Resource | What it does |
| --- | --- |
| Notification channel (e-mail) | Where every alert and budget warning goes |
| Alert: CPU high | Opens an incident when `lab02-secure-vm` stays above 80% CPU for 5 minutes |
| Alert: VM silent | Opens an incident when the VM stops sending its uptime metric for 5 minutes (stopped or frozen) |
| Log-based metric + alert | Counts `SetIamPolicy` calls in the audit logs and alerts on any change to who has access |
| Monthly budget | Warns at 50%, 90% and 100% of the amount, and also when the **forecast** passes 100% |
| APIs | Turns on Monitoring, Logging and Billing Budgets (and leaves them on if the lab is destroyed) |

Every alert has a short note telling whoever receives it what to check first.

## Why I built it this way

- **CPU without an agent.** The CPU metric comes from the hypervisor, so it works without installing the Ops Agent on the VM. Memory and disk would need the agent; I left that for when the VM runs a real workload.
- **"Absent" instead of "below".** When a VM stops, its metrics simply stop arriving. A normal threshold never fires on missing data. The `condition_absent` turns that silence into an alert.
- **Security alert for free.** Admin Activity audit logs are always on and cost nothing. Turning them into a metric is a cheap way to know when permissions change, which is one of the first things an attacker does.
- **Forecasted spend.** A budget never stops spending, it only warns. The forecast rule gives the warning while there is still time to act.
- **Variables checked before any API call:** project ID, e-mail, billing account format, currency and the CPU threshold.

## Checkov

No findings. The resources in this lab are monitoring and billing objects, which Checkov does not flag.

## How to run

You need the project's billing account ID and the `roles/billing.costsManager` role (or Billing Account Administrator) to create the budget, plus `roles/monitoring.editor` and `roles/logging.configWriter` on the project.

```powershell
cd projects/04-monitoring-alerts
Copy-Item terraform.tfvars.example terraform.tfvars
# set project_id, alert_email, billing_account, monthly_budget and currency_code
terraform init -lockfile=readonly
terraform plan
```

State goes to the Lab 03 bucket under `labs/04-monitoring-alerts` ([`backend.tf`](backend.tf)).

To validate without credentials, as CI does:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

## How to test after deploying

- Confirm the e-mail channel (Google sends a verification message).
- Grant and remove any role in IAM: the security alert should arrive within a couple of minutes.
- Stop the VM: the "VM silent" alert should open after about 5 minutes, and close after it starts again.
- In Billing > Budgets, check that the budget shows the project and the thresholds.

## Cost

Alert policies, notification channels, budgets and a log-based metric with low volume fall within the free monitoring and logging allowances. The VM it watches is the Lab 02 VM, so nothing new is billed by this lab.

## Checklist

- [x] Terraform written (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt`, `validate` and Checkov passing locally and in CI
- [ ] Deployed and alerts tested (security alert, VM silent, budget)
