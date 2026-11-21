# Lab 06 - Workload Identity Federation (CI without keys)

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed on 2026-11-21 (17 resources, `terraform plan` with no changes afterwards). The workflow is active in [`.github/workflows/terraform-plan.yml`](../../.github/workflows/terraform-plan.yml).

Today my CI only checks syntax, because it has no access to the cloud. The usual shortcut is to create a service account key, paste the JSON into a GitHub secret and forget it there for years. That key is the classic leak. This lab gives GitHub Actions access to Google Cloud with no stored key at all: GitHub proves who it is with a short-lived token, and Google trades it for temporary credentials.

## How the token exchange works

```text
GitHub Actions job (pull request in matheuslab-bit/google-cloud-portfolio)
   │  1. asks GitHub for an OIDC token (id-token: write)
   ▼
Workload Identity Pool "github-actions" / provider "github-oidc"
   │  2. checks the issuer and the condition: repository ID AND immutable sub = repo:OWNER@ID/NAME@ID:pull_request
   ▼
Security Token Service
   │  3. returns a federated token
   ▼
Service account "github-terraform-plan" (read-only)
   │  4. short-lived credentials, valid for about an hour
   ▼
terraform plan against the real project and the remote state
```

## What it creates

| Resource | Detail |
| --- | --- |
| Workload identity pool `github-actions` | Where external identities from GitHub land |
| OIDC provider `github-oidc` | Trusts `token.actions.githubusercontent.com` and maps the token claims (sub, repository, owner, ref) |
| Service account `github-terraform-plan` | No keys. Only this repository can impersonate it |
| Read-only roles | Compute, service accounts, IAM policies, enabled APIs, Monitoring, Logging, Cloud Run, Artifact Registry and secret metadata |
| Access to the state bucket | Only objects under `labs/`, needed to create and delete the `.tflock` during `plan` |
| Example workflow | [`examples/terraform-plan.yml`](examples/terraform-plan.yml), kept as reference; the active copy is in `.github/workflows/terraform-plan.yml` |

## Decisions I made

- **The condition is the security.** A provider without `attribute_condition` accepts tokens from any GitHub repository in the world. Mine checks the repository ID and pins the `sub` claim to `repo:matheuslab-bit@343780539/google-cloud-portfolio@1466069275:pull_request`, so only pull request runs of this repository get in. Applying from `main` would need a second, separate identity.
- **Immutable subject.** This repository uses GitHub's immutable `sub` format, with the owner and repository IDs next to the names. My first condition expected the old `repo:OWNER/NAME:pull_request` format and GitHub's token was rejected (`rejected by the attribute condition`) in the first test run. I fixed it by building the `sub` from `github_repository_id` and `github_repository_owner_id` (read with `gh api repos/OWNER/NAME`). The IDs also stop a deleted and recreated repository with the same name from getting in.
- **No Viewer role.** Checkov flagged `roles/viewer` (CKV_GCP_117), and it was right: it reads almost everything. I replaced it with the specific read-only roles that `plan` needs for these labs.
- **Even `plan` writes one thing.** It creates and deletes the `.tflock` object in the state bucket. An IAM condition limits that write access to the `labs/` prefix.
- **Secret values stay out.** `roles/secretmanager.viewer` shows secret metadata, not the content. Reading values would need `secretAccessor`, which CI does not get.

## Checkov

47 passed, 0 failed, 1 skipped with a reason in [`main.tf`](main.tf):

| Check | Why |
| --- | --- |
| `CKV_GCP_125`, GitHub OIDC trust condition | False positive. Checkov does not resolve `var.github_repository` inside the condition. I confirmed it: with the repository written literally, the same condition passes. |

## How to run

You need `roles/iam.workloadIdentityPoolAdmin`, `roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin` and `roles/storage.admin` on the state bucket.

```powershell
cd projects/06-workload-identity-federation
Copy-Item terraform.tfvars.example terraform.tfvars   # project_id, github_repository, state_bucket
terraform init -lockfile=readonly
terraform apply
terraform output
```

Then, in GitHub (Settings > Secrets and variables > Actions > Variables), create `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` and `GCP_PROJECT_ID` with the outputs, and copy [`examples/terraform-plan.yml`](examples/terraform-plan.yml) to `.github/workflows/`. These are variables, not secrets: none of them is sensitive.

## How to test after deploying

- Open a pull request that touches `projects/`: the plan job should authenticate and show `No changes` for labs 01 and 02.
- Run the same workflow from a fork or another repository: authentication must fail.
- In Cloud Logging, the `sts.googleapis.com` entries show each token exchange and which repository asked for it.

## Cost

Workload Identity Federation, the Security Token Service and service accounts have no cost.

## Checklist

- [x] Terraform written: pool, provider with a pinned condition, keyless service account, narrow roles and conditional bucket access
- [x] Example workflow ready to enable
- [x] `terraform fmt`, `validate` and Checkov passing locally and in CI
- [x] Deployed on 2026-11-21 and repository variables created
- [x] `terraform plan` running in a pull request without any key: PR #5, `No changes` in labs 01 and 02 (2026-11-21)
