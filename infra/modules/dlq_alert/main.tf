resource "azurerm_monitor_action_group" "this" {
  name                = "ag-${var.name_prefix}-oncall"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace("oncall${var.name_prefix}", "-", ""), 0, 12)
  tags                = var.tags

  email_receiver {
    name                    = "oncall-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Fires when any message sits in the queue's dead-letter sub-queue. A non-empty DLQ
# means customer messages were NOT processed, so the threshold is "> 0", not a rate.
# Filtering on the EntityName dimension scopes the alert to this queue only.
resource "azurerm_monitor_metric_alert" "dlq" {
  for_each = toset(var.queue_names)

  name                = "alert-${var.name_prefix}-${each.key}-dlq"
  resource_group_name = var.resource_group_name
  scopes              = [var.servicebus_namespace_id]
  description         = "Messages are accumulating in the dead-letter queue of '${each.key}'."
  severity            = var.severity
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.threshold

    dimension {
      name     = "EntityName"
      operator = "Include"
      values   = [each.key]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
