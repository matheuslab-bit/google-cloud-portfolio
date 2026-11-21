terraform {
  backend "gcs" {
    bucket = "gcp-portfolio-tfstate-usc1-7f4e9a2c"
    prefix = "labs/06-workload-identity-federation"
  }
}
