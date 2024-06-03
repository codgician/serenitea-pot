{ config, ... }: {
  resource.azurerm_cognitive_deployment.akasha-gpt-4 = {
    name = "akasha-gpt-4";
    cognitive_account_id = config.resource.azurerm_cognitive_account.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.Default";

    model = {
      format = "OpenAI";
      name = "gpt-4";
      version = "turbo-2024-04-09";
    };

    scale = {
      type = "Standard";
      capacity = 30;
    };
  };
}
