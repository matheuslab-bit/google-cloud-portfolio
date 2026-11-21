# Lab 04 - Monitoring, alerts and budget

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed on 2026-11-21 (9 resources, `terraform plan` with no changes afterwards). Alerts triggered in a test the same day; e-mail delivery still to be checked.

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
- **Promotional credits do not hide spending.** The budget subtracts Free Tier and automatic discounts, but not promotional credits (free trial and monthly credits). If it subtracted everything, spending would show as zero while credits pay the bill, and the warning would only arrive once they ran out. My goal is to spend less than US$ 10 a month; since the billing account is in BRL, the budget is R$ 50, a little below that goal.
- **Variables checked before any API call:** project ID, e-mail, billing account format, currency and the CPU threshold.

## Checkov

No findings. The resources in this lab are monitoring and billing objects, which Checkov does not flag.

## How to run

You need the project's billing account ID and the `roles/billing.costsManager` role (or Billing Account Administrator) to create the budget, plus `roles/monitoring.editor` and `roles/logging.configWriter` on the project.

The Cloud Resource Manager API must be enabled before the first `plan`. Terraform reads the project number through it (the budget only accepts `projects/<number>`), and that read happens before the lab enables any API itself. Without it, `plan` fails with a 403 `SERVICE_DISABLED` error. Enabling it is free:

```powershell
gcloud services enable cloudresourcemanager.googleapis.com --project=YOUR_PROJECT
```

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
- [x] Deployed on 2026-11-21
- [x] Alerts triggered on 2026-11-21: IAM (the log metric counted 2 `SetIamPolicy` calls after granting and removing `roles/viewer`) and VM silent (VM stopped for about 7 minutes, uptime metric gap confirmed); budget checked in Cloud Billing
- [ ] Alert e-mails checked in the inbox
