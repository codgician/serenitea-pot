{ config, ... }: {
  resource.azurerm_cognitive_deployment.akasha-gpt-4o = {
    name = "akasha-gpt-4o";
    cognitive_account_id = config.resource.azurerm_cognitive_account.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.Default";

    model = {
      format = "OpenAI";
      name = "gpt-4o";
      version = "2024-05-13";
    };

    scale = {
      type = "GlobalStandard";
      capacity = 20;
    };
  };
}
