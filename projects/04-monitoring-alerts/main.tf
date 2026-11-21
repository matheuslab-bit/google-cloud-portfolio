data "google_project" "this" {
  project_id = var.project_id
}

locals {
  apis = [
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "billingbudgets.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project = var.project_id
  service = each.value
  # Keep the APIs on if this lab is destroyed; other labs may depend on them.
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Portfolio alerts (e-mail)"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.apis]
}

# CPU is measured by the hypervisor, so this works without installing the Ops Agent on the VM.
resource "google_monitoring_alert_policy" "vm_cpu_high" {
  project      = var.project_id
  display_name = "VM ${var.vm_instance_name}: CPU above ${var.cpu_threshold * 100}% for 5 minutes"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization high"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\" AND metric.labels.instance_name = \"${var.vm_instance_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    content   = "CPU of `${var.vm_instance_name}` stayed above the threshold for 5 minutes. Connect with `gcloud compute ssh ${var.vm_instance_name} --tunnel-through-iap` and check the top processes."
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# The uptime metric stops arriving when the VM is stopped or hangs; "absent" turns that silence into an alert.
resource "google_monitoring_alert_policy" "vm_down" {
  project      = var.project_id
  display_name = "VM ${var.vm_instance_name}: no data for 5 minutes (stopped or unresponsive)"
  combiner     = "OR"

  conditions {
    display_name = "Uptime metric absent"

    condition_absent {
      filter   = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/uptime\" AND metric.labels.instance_name = \"${var.vm_instance_name}\""
      duration = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content   = "No uptime data from `${var.vm_instance_name}`. Check whether it was stopped on purpose: `gcloud compute instances describe ${var.vm_instance_name} --zone us-central1-a --format='value(status)'`."
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# Admin Activity audit logs are always on and free, so this security alert costs nothing extra.
resource "google_logging_metric" "iam_policy_changes" {
  project     = var.project_id
  name        = "portfolio/iam_policy_changes"
  description = "Counts SetIamPolicy calls (someone changed who has access to what)."
  filter      = "logName:\"cloudaudit.googleapis.com%2Factivity\" AND protoPayload.methodName=\"SetIamPolicy\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "iam_policy_changed" {
  project      = var.project_id
  display_name = "Security: IAM policy changed in ${var.project_id}"
  combiner     = "OR"

  conditions {
    display_name = "SetIamPolicy detected"

    condition_threshold {
      filter          = "resource.type = \"global\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.iam_policy_changes.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    mime_type = "text/markdown"
    content   = "Someone changed an IAM policy. Find who and what in Logs Explorer with: `protoPayload.methodName=\"SetIamPolicy\"`. If it was not a planned change, review it right away."
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

# A budget does not stop spending; it only warns. Forecasted spend gives the warning before the money is gone.
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "Portfolio - ${var.project_id} - monthly"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.currency_code
      units         = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.apis]
}
