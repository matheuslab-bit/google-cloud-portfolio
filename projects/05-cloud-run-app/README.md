# Lab 05 - App on Cloud Run with Artifact Registry and Secret Manager

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Status:** deployed on 2026-11-21 (stage 1: 7 resources; stage 2: the Cloud Run service; `terraform plan` with no changes afterwards).

Labs 01 to 03 are about infrastructure. This one runs an application: a small status API in Node.js, packaged as a container, stored in Artifact Registry and served by Cloud Run. It also reads a secret from Secret Manager the right way.

## How it fits together

```text
docker build/push ──> Artifact Registry (us-central1, repo "apps")
                             │
                             ▼
Me ── identity token ──> Cloud Run "status-api"  (runs as lab05-status-api)
                             │
                             └── reads APP_GREETING from Secret Manager (only this secret)
```

## What it creates

| Resource | Detail |
| --- | --- |
| Artifact Registry repository `apps` | Docker format, with cleanup rules: keeps the 5 most recent versions and deletes untagged images after 7 days |
| Service account `lab05-status-api` | Runtime identity of the service, with access to one secret and nothing else |
| Secret `lab05-app-greeting` | Only the container; the value is added with `gcloud` |
| Cloud Run service `status-api` | 0 to 2 instances, 1 vCPU, 256 MiB, CPU billed only during requests, startup and liveness checks on `/healthz` |
| Public access | Off by default (`allow_public_access = false`) |

## Decisions I made

- **The secret value never touches Terraform.** If Terraform created the secret version, the value would be stored in plain text in the state file. Terraform creates only the secret; I add the value with `gcloud secrets versions add`.
- **Private by default.** Cloud Run services often get `allUsers` by habit. Here you call it with your own identity token, and public access is an explicit opt-in.
- **One identity per service.** The default compute service account has Editor on the project. This service runs with its own account that can read a single secret.
- **Two-step deploy.** The first `apply` creates the registry, the secret and the account (the service needs an image that does not exist yet). After pushing the image, the second `apply` with `image` set creates the service.
- **Costs under control.** Scale to zero, a cap of 2 instances, CPU only during requests and cleanup rules in the registry.
- **App ready for Cloud Run:** listens on `$PORT`, logs one JSON line per request (Cloud Logging reads it as structured data), and finishes in-flight requests on `SIGTERM`. The image runs as a non-root user.

## Checkov

0 failed, 1 skipped with a reason in [`main.tf`](main.tf):

| Check | Why |
| --- | --- |
| `CKV_GCP_84`, registry encrypted with my own key | Google-managed encryption is enough for a lab; customer-managed keys are planned for a Cloud KMS lab. |

## How to run

```powershell
cd projects/05-cloud-run-app
Copy-Item terraform.tfvars.example terraform.tfvars   # set project_id, leave image empty
terraform init -lockfile=readonly
terraform apply                                        # registry, secret and service account

# add the secret value without it touching Terraform
"hello from Secret Manager" | gcloud secrets versions add lab05-app-greeting --data-file=-

# build and push the image
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/PROJECT_ID/apps/status-api:1.0.0 app
docker push us-central1-docker.pkg.dev/PROJECT_ID/apps/status-api:1.0.0

# deploy the service
terraform apply -var "image=us-central1-docker.pkg.dev/PROJECT_ID/apps/status-api:1.0.0"
```

Call the private service with an identity token:

```bash
URL=$(terraform output -raw service_url)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/"
# {"service":"status-api","revision":"status-api-00001-abc","version":"1.0.0","uptimeSeconds":12,"greetingConfigured":true}
```

Run the app locally and its tests:

```bash
cd app
npm test
PORT=8080 node server.js
```

## What I learned deploying it

- **`/healthz` is not reachable from outside.** Cloud Run reserves URL paths that end in `z`, so a request to `$URL/healthz` gets a 404 page from Google, not from the app. The startup and liveness probes still work, because they call the container directly. For an external health check, a path like `/health` would be needed.
- **The Docker build created three versions in the registry.** Recent Docker versions add provenance attachments, so one push stored a tagged image and two untagged entries. The "keep the 5 most recent" rule protects them for now; `docker build --provenance=false` creates a single manifest and keeps the repository clean.

## Cost

Cloud Run's free tier covers 2 million requests and 180,000 vCPU-seconds a month, and the service scales to zero when idle. Artifact Registry includes 0.5 GB of free storage, and the cleanup rules keep the repository small. Secret Manager has free monthly allowances for active versions and access calls. Free tier limits are shared across the billing account; the budget from [Lab 04](../04-monitoring-alerts/README.md) warns if something grows.

## Cleanup

```powershell
terraform destroy
gcloud secrets delete lab05-app-greeting   # only if the secret was left behind
```

## Checklist

- [x] Terraform written, with two-step deploy and opt-in public access
- [x] App with tests (`npm test`) and Dockerfile with a non-root user
- [x] `terraform fmt`, `validate` and Checkov passing locally and in CI
- [x] Deployed, called with an identity token and secret injection confirmed (`greetingConfigured: true`) on 2026-11-21; without a token the service returns 403
