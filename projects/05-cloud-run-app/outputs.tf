output "repository" {
  description = "Docker repository path for docker push."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
}

output "service_account" {
  description = "Runtime service account of the Cloud Run service."
  value       = google_service_account.run.email
}

output "service_url" {
  description = "Service URL (empty until an image is deployed)."
  value       = local.deploy_service ? google_cloud_run_v2_service.status_api[0].uri : ""
}
