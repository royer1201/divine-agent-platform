output "action_group_id" {
  value = azurerm_monitor_action_group.this.id
}

output "alert_ids" {
  value = { for q, a in azurerm_monitor_metric_alert.dlq : q => a.id }
}
