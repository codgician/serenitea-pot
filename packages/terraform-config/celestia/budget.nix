{ config, ... }:
{
  resource = {
    azurerm_consumption_budget_resource_group.celestia = {
      name = "celestia-budget";
      resource_group_id = config.resource.azurerm_resource_group.celestia "id";
      amount = 150;
      time_grain = "Monthly";

      time_period = {
        start_date = "2024-04-01T00:00:00Z";
        end_date = "9999-12-31T23:59:59Z";
      };

      notification = [
        {
          enabled = true;
          threshold = "100.0";
          threshold_type = "Forecasted";
          operator = "GreaterThanOrEqualTo";
          contact_emails = [ "i@codgician.me" ];
          contact_roles = [ "Owner" ];
        }
      ];
    };

    azurerm_cost_anomaly_alert.celestia-cost-anomaly-alert = {
      name = "celestia-cost-anomaly-alert";
      display_name = "Celestia cost anomaly alert";
      email_subject = "Celestia cost anomaly alert";
      email_addresses = [ "i@codgician.me" ];
    };
  };
}
