output "notification_channel" {
  description = "E-mail notification channel used by all alerts and the budget."
  value       = google_monitoring_notification_channel.email.id
}

output "alert_policies" {
  description = "Display names of the alert policies created by this lab."
  value = [
    google_monitoring_alert_policy.vm_cpu_high.display_name,
    google_monitoring_alert_policy.vm_down.display_name,
    google_monitoring_alert_policy.iam_policy_changed.display_name,
  ]
}

output "budget" {
  description = "Budget resource name."
  value       = google_billing_budget.monthly.name
}
