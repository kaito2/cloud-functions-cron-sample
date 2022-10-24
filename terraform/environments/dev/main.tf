terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.41.0"
    }
  }
}

provider "google" {
  # Configuration options
}

module "cloud_function" {
  source = "../../modules/cloud_functions"

  project_id = "YOUR_PROJECT_ID"
  app_name   = "sample"
}
