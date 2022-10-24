// Setup function code
data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

resource "google_storage_bucket" "main" {
  project = var.project_id

  location = "ASIA"
  name     = "${var.app_name}-functions"
}

resource "google_storage_bucket_object" "function" {
  bucket = google_storage_bucket.main.name
  name   = "${data.archive_file.function.output_md5}.zip"
  source = data.archive_file.function.output_path
}

// Secrets
// TODO: Replace this.
resource "google_secret_manager_secret" "super_secret_value" {
  project = var.project_id

  secret_id = "super-secret-value"

  replication {
    user_managed {
      replicas {
        location = "asia-northeast1"
      }
    }
  }
}
resource "google_secret_manager_secret_iam_member" "super_secret_value" {
  project = var.project_id

  secret_id = google_secret_manager_secret.super_secret_value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.main.email}"
}

// Cloud PubSub for Cloud Scheduler
resource "google_pubsub_topic" "main" {
  project = var.project_id

  name = "${var.app_name}-trigger"
}

resource "google_cloud_scheduler_job" "main" {
  project = var.project_id

  region    = "asia-northeast1"
  name      = "${var.app_name}-trigger"
  schedule  = "*/5 * * * *" #OR every 5 minutes
  time_zone = "Asia/Tokyo"
  pubsub_target {
    topic_name = google_pubsub_topic.main.id
    data       = base64encode("Pub/Sub")
  }
}

// Function
resource "google_service_account" "main" {
  project = var.project_id

  account_id   = "gcf-sa-${var.app_name}"
  display_name = "Managed by terraform"
}

resource "google_cloudfunctions2_function" "main" {
  project     = var.project_id
  location    = "asia-northeast1"
  name        = var.app_name
  description = "Managed by terraform"

  build_config {
    runtime     = "python310"
    entry_point = "run"

    # TODO: Modify
    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }

    source {
      storage_source {
        bucket = google_storage_bucket.main.name
        object = google_storage_bucket_object.function.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
    }
    secret_environment_variables {
      key        = "SUPER_SECRET_VALUE"
      project_id = var.project_id
      secret     = google_secret_manager_secret.super_secret_value.secret_id
      version    = "latest"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.main.email
  }

  event_trigger {
    trigger_region = "asia-northeast1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.main.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}
