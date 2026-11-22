output "router" {
  description = "Cloud Router that hosts the NAT configuration."
  value       = google_compute_router.nat.name
}

output "nat" {
  description = "Cloud NAT gateway name."
  value       = google_compute_router_nat.nat.name
}

output "nat_subnet" {
  description = "The only subnet whose VMs use this gateway."
  value       = data.google_compute_subnetwork.lab02.name
}

output "test_command" {
  description = "Checks outbound access from the private VM through IAP."
  value       = "gcloud compute ssh lab02-secure-vm --zone=us-central1-a --tunnel-through-iap --command='curl -sS -o /dev/null -w %%{http_code} https://deb.debian.org/'"
}
