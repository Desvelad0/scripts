terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.19.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "sentinel-rg" {
  name     = "sentinel-demo"
  location = "West Europe"


}

resource "azurerm_log_analytics_workspace" "sentinel_workspace" {
  name                = "sentinel-demo-workspace"
  location            = azurerm_resource_group.sentinel-rg.location
  resource_group_name = azurerm_resource_group.sentinel-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.sentinel_workspace.id
  depends_on   = [azurerm_log_analytics_workspace.sentinel_workspace]
}


resource "time_sleep" "wait_for_sentinel" {
  depends_on      = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
  create_duration = "60s"
}


resource "azurerm_monitor_data_collection_rule" "sentinel_dcr" {
  name                = "sentinel-dcr"
  location            = azurerm_resource_group.sentinel-rg.location
  resource_group_name = azurerm_resource_group.sentinel-rg.name

  destinations {
    log_analytics {
      name                  = "logAnalytics"
      workspace_resource_id = azurerm_log_analytics_workspace.sentinel_workspace.id
    }
  }

  data_sources {
  windows_event_log {
    streams = ["Microsoft-WindowsEvent"]
    name    = "application-logs"
    x_path_queries = [
      "Application!*[System[(Level=1 or Level=2 or Level=3)]]"
    ]
  }
  windows_event_log {
    streams = ["Microsoft-SecurityEvent"]
    name    = "security-logs"
    x_path_queries = [
      "Security!*[System[(EventID=4625)]]"
    ]
  }
  windows_event_log {
    streams = ["Microsoft-SystemEvent"]
    name    = "system-logs"
    x_path_queries = [
      "System!*[System[(Level=1 or Level=2 or Level=3)]]"
    ]
  }
}


  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["logAnalytics"]
  }

  depends_on = [
    azurerm_log_analytics_workspace.sentinel_workspace,
    azurerm_sentinel_log_analytics_workspace_onboarding.sentinel
  ]
}
# BITS Activity Alert
resource "azurerm_sentinel_alert_rule_scheduled" "bits_alert" {
  name                       = "BITS-Activity-Alert"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel_workspace.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
  display_name               = "BITS Event Detected (EventID 16398)"
  severity                   = "Medium"
  query                      = <<QUERY
    Event
    | where EventID == 16398
  QUERY
  query_frequency            = "PT30M"
  query_period               = "PT30M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 5
  suppression_duration       = "P1D"
  suppression_enabled        = true

}
# Login Failure Alert
resource "azurerm_sentinel_alert_rule_scheduled" "login_failure_alert" {
  name                       = "Login-Failure-Alert"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel_workspace.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
  display_name               = "Failed Logins Detected (EventID 4625)"
  severity                   = "High"
  query                      = <<QUERY
    Event
    | where EventID == 4625
    | extend FailedAccount = extract(@"Account For Which Logon Failed:\s+Security ID:\s+\S+\s+Account Name:\s+(\S+)", 1, RenderedDescription)
    | project TimeGenerated, FailedAccount, Computer
    | sort by TimeGenerated desc
  QUERY
  query_frequency            = "PT5M"
  query_period               = "PT5H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 3
}
