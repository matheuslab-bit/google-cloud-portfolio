locals {
  apis = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
  ]
  deploy_service = var.image != ""
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "apps" {
  #checkov:skip=CKV_GCP_84:Images are encrypted with Google-managed keys; customer-managed keys are planned for a future Cloud KMS lab.
  project       = var.project_id
  location      = var.region
  repository_id = "apps"
  description   = "Container images for the portfolio labs"
  format        = "DOCKER"

  # Old images cost storage. Keep the 5 most recent versions and delete untagged images after 7 days.
  cleanup_policies {
    id     = "keep-last-5"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  depends_on = [google_project_service.apis]
}

# Runtime identity of the service: it can read one secret and nothing else.
resource "google_service_account" "run" {
  project      = var.project_id
  account_id   = "lab05-status-api"
  display_name = "Lab 05 Cloud Run service (reads one secret only)"
}

# Only the secret container is managed here. The value is added with gcloud, so it never lands in the Terraform state.
resource "google_secret_manager_secret" "greeting" {
  project   = var.project_id
  secret_id = "lab05-app-greeting"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "run_reads_greeting" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.greeting.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run.email}"
}

resource "google_cloud_run_v2_service" "status_api" {
  count = local.deploy_service ? 1 : 0

  project             = var.project_id
  name                = "status-api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        # Bill CPU only while a request is being handled.
        cpu_idle = true
      }

      env {
        name  = "APP_VERSION"
        value = element(split(":", var.image), length(split(":", var.image)) - 1)
      }

      env {
        name = "APP_GREETING"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.greeting.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds    = 3
        failure_threshold = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds = 30
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.run_reads_greeting]
}

# Off by default: the service is reached with an identity token. Turn on only for a public demo.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = local.deploy_service && var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.status_api[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
