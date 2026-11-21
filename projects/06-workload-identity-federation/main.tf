locals {
  apis = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Identities coming from GitHub Actions OIDC tokens"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_125:False positive. Checkov does not resolve var.github_repository inside attribute_condition; the condition pins both the repository and the sub claim (repo:OWNER/NAME:pull_request).
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Without a condition, a workflow in ANY GitHub repository could ask for a token.
  # Pinning the "sub" claim allows only pull request runs of this one repository.
  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.sub == 'repo:${var.github_repository}:pull_request'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The identity the workflow becomes after the token exchange. It has no keys.
resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "github-terraform-plan"
  display_name = "GitHub Actions - terraform plan (read-only)"
}

# Only workflows from the configured repository can impersonate the service account.
resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# terraform plan only reads. Instead of the broad Viewer role, grant the read-only roles the labs need.
locals {
  ci_read_roles = [
    "roles/compute.viewer",                  # Labs 01 and 02: VPC, subnets, firewall, VM
    "roles/iam.serviceAccountViewer",        # service accounts created by the labs
    "roles/iam.securityReviewer",            # IAM policies that plan compares
    "roles/serviceusage.serviceUsageViewer", # enabled APIs (google_project_service)
    "roles/monitoring.viewer",               # Lab 04 alert policies and channels
    "roles/logging.viewer",                  # Lab 04 log-based metric
    "roles/run.viewer",                      # Lab 05 Cloud Run service
    "roles/artifactregistry.reader",         # Lab 05 repository
    "roles/secretmanager.viewer",            # Lab 05 secret metadata (not the value)
  ]
}

resource "google_project_iam_member" "ci_read" {
  for_each = toset(local.ci_read_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci.email}"
}

# Even a read-only plan creates and deletes the .tflock object, so CI needs write access to the state objects.
# The condition limits it to the labs/ prefix of the state bucket.
resource "google_storage_bucket_iam_member" "ci_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.ci.email}"

  condition {
    title       = "only-lab-state"
    description = "Read and lock only the Terraform state objects under labs/"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.state_bucket}/objects/labs/\") || resource.type == \"storage.googleapis.com/Bucket\""
  }
}
