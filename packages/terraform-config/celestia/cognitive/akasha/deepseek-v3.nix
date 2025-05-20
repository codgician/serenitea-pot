{ config, ... }:
{
  resource.azapi_resource.akasha-deepseek-v3 = {
    name = "akasha-deepseek-v3";
    type = "Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-10-01";
    parent_id = config.resource.azurerm_ai_foundry_project.akasha-ai-project "id";
    location = config.resource.azurerm_ai_foundry_project.akasha-ai-project.location;

    body = {
      properties = {
        authMode = "Key";
        contentSafety.contentSafetyStatus = "Disabled";
        modelSettings.modelId = "azureml://registries/azureml-deepseek/models/DeepSeek-V3-0324";
      };

      sku.name = "Consumption";
    };
  };
}
