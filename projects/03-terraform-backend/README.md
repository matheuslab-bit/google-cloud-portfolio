# Lab 03 - Terraform state in Cloud Storage

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed in Iowa (`us-central1`) on 2026-11-20. It holds the current Terraform state of Lab 01 (`labs/01-vpc-network`) and Lab 02 (`labs/02-secure-compute-engine`). Temporary `.tflock` objects show up while a lock is held.

A dedicated, locked-down Cloud Storage bucket to keep the Terraform state of the other labs. The code and CI were merged in [PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9). On 2026-11-20 I created the bucket, moved the state of labs 01 and 02 into it with `terraform init -migrate-state` and added their `backend.tf` files in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

## Why

Before this lab, each lab kept its `.tfstate` on my disk. If the disk died, or if two runs happened at the same time, the state could be lost or corrupted. With a shared bucket I get locking, older versions I can recover and a lifecycle rule that keeps costs under control.

## Layout

```text
Lab 03 (local state, the starting point)
  └── creates and manages the bucket (us-central1, STANDARD)
        ├── labs/01-vpc-network/default.tfstate            <- Lab 01
        └── labs/02-secure-compute-engine/default.tfstate  <- Lab 02
```

Bucket settings: uniform bucket-level access, public access prevention enforced, versioning on, 7-day Soft Delete (604800 s), `force_destroy = false`, `deletion_policy = "PREVENT"`, `prevent_destroy = true` and deletion of archived versions after 90 days.

### Who keeps the state of the state bucket?

This lab keeps its own `terraform.tfstate` **local**, with a backup copy in another folder outside the repository. A local copy on the same disk does not protect against a disk failure, so it is not a real backup.

Keeping a bucket's state inside the bucket itself creates a chicken-and-egg problem when you create, recover or delete it. Since Lab 03 manages a single, stable resource, a local state with a separate copy is simple and avoids locking myself out.

The other labs (01, 02 and future ones) point to this bucket with `backend "gcs"` blocks, each under its own prefix, so each one has an independent state.

## How the GCS backend works

**Locking.** Before any command that reads or changes state (`plan`, `apply`, `destroy`, `import`), Terraform creates a temporary `.tflock` object next to `default.tfstate`. It does this even for `plan`, which does not write anything. If a second run starts at the same time, it stops right away instead of corrupting the state.

**Versioning.** Every `terraform apply` writes a new version of `default.tfstate`. The previous one is not overwritten: GCS keeps it as a noncurrent (`ARCHIVED`) version with its own generation number.

**90-day rule** (`days_since_noncurrent_time = 90`, `with_state = "ARCHIVED"`). Old versions are deleted after 90 days. The current state is never deleted by this rule, no matter how long it goes without a new `apply`. GCS runs these rules in the background, so the deletion can happen some time after day 90.

**7-day Soft Delete** (`retention_duration_seconds = 604800`). I set it explicitly instead of trusting the default. When a version is deleted (by the 90-day rule or by hand), it stays recoverable for 7 more days.

In total, an old state version can be recovered for about 90 days as a noncurrent version, plus 7 days in Soft Delete.

## Security

- **`uniform_bucket_level_access = true`:** no per-object ACLs. Access is controlled only by IAM.
- **`public_access_prevention = "enforced"`:** blocks `allUsers` and `allAuthenticatedUsers`, so the state can never be made public by accident.
- **`force_destroy = false`:** Terraform cannot empty and delete the bucket while it has state in it.
- **`deletion_policy = "PREVENT"`:** deletion protection in the Google provider `7.46.2`.
- **`lifecycle.prevent_destroy = true`:** Terraform rejects any plan that would destroy the bucket.

These three protections only stop accidents that go **through Terraform**. They do not replace backups, and they do not stop someone with permission from deleting the bucket in the Console, with `gcloud storage rm` or through the API.

`project_id` and `bucket_name` are required variables set in a local `terraform.tfvars` (ignored by Git). Use a bucket name that does not reveal anything, like `gcp-portfolio-tfstate-usc1-<random-suffix>`, without your project ID or personal data.

### Checkov

Versioning, uniform access and public access prevention pass. One finding is accepted and explained with `#checkov:skip` in [`main.tf`](main.tf):

| Check | Why |
| --- | --- |
| `CKV_GCP_62`, bucket access logging | It would need a second bucket just for logs. Changes to the bucket are already recorded in Cloud Audit Logs (Admin Activity). |

### Permissions

- **To create the bucket (this lab):** `storage.buckets.create`, `storage.buckets.get` and `storage.buckets.update` in the project (for example `roles/storage.admin`, or a custom role).
- **To use the backend in other labs (`plan` / `apply`):** read and write on the objects (`roles/storage.objectAdmin` on this bucket, or `storage.objects.get`, `list`, `create` and `delete`).
- **For `terraform plan` in CI** (with Workload Identity Federation, in a future lab): even a read-only `plan` needs to create and delete the `.tflock` (`storage.objects.create` and `storage.objects.delete` on the prefix). Turning off locking on a shared state is a bad idea, because two runs at once could read inconsistent data.
- **To restore soft-deleted objects:** `storage.objects.list`, `storage.objects.get`, `storage.objects.restore` and `storage.objects.create` on the bucket.

## Cost

The Free Tier includes **5 GB-month of Regional Standard Storage** in some US regions (including `us-central1`), plus a monthly allowance of Class A and Class B operations, following Google's current terms.

- The state of labs 01 and 02 adds up to **about 24 KB** (`4.88 KB` + `19.10 KB`).
- Even with dozens of old versions kept for 90 days, it stays far below 5 MB.
- The Free Tier is shared across the billing account. Going over the operation limits, cross-region egress or other projects can cost money. Billing alerts do not block spending.

## Recovering the state

> **Before anything:** copy the current `default.tfstate` (if it exists) somewhere safe before restoring an older version. If you pick the wrong version, you can still go back.

### A. Restore an old version (within the 90 days)

1. Save the current state:
   ```powershell
   gcloud storage cp gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate ./pre-recovery-default.tfstate.bak
   ```
2. List all versions of the lab's state:
   ```powershell
   gcloud storage ls --all-versions gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate
   ```
3. Look at the dates and pick the `<GENERATION>` of the last good version.
4. Copy that version back as the current state:
   ```powershell
   gcloud storage cp gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate#<GENERATION> gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate
   ```
5. Run `terraform plan` in the lab folder and confirm the state matches what is in the cloud.

### B. Restore a deleted version (within the 7 days of Soft Delete)

If the state or an old version was deleted (by hand or by the 90-day rule), it can still be recovered for 7 days. You need `storage.objects.list`, `get`, `restore` and `create` on the bucket.

1. Save the current state:
   ```powershell
   gcloud storage cp gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate ./pre-soft-restore-default.tfstate.bak
   ```
2. List the deleted versions:
   ```powershell
   gcloud storage ls --soft-deleted gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate
   ```
3. Pick the `<GENERATION>` and restore it:
   ```powershell
   gcloud storage restore gs://YOUR_BUCKET_NAME/labs/01-vpc-network/default.tfstate#<GENERATION>
   ```
4. Run `terraform plan` in the lab folder to confirm.

## How to run

Always from `projects/03-terraform-backend/`:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

To plan against the deployed bucket, with a local `terraform.tfvars` copied from `terraform.tfvars.example`:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# put the real project_id and a globally unique bucket_name in terraform.tfvars
terraform plan -input=false
```

Do not commit `terraform.tfvars`, `*.tfplan` or `*.tfstate`.

## Checklist

- [x] Terraform files written (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`)
- [x] Documentation in English and Portuguese (`README.md` and `README.pt-BR.md`)
- [x] `terraform fmt -check`, `terraform init -backend=false` and `terraform validate` passed locally and in GitHub Actions ([PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9))
- [x] Bucket created in Google Cloud (`us-central1`, 2026-11-20)
- [x] State of labs 01 and 02 moved with `terraform init -migrate-state` (`No changes` checked) and `backend.tf` files added in [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10)
