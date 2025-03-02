{ config, ... }:
{
  resource.azapi_resource.akasha-deepseek-r1 = {
    name = "akasha-deepseek-r1";
    type = "Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-10-01-preview";
    parent_id = config.resource.azurerm_ai_foundry_project.akasha-ai-project "id";
    location = config.resource.azurerm_ai_foundry_project.akasha-ai-project.location;

    body = {
      properties = {
        authMode = "Key";
        contentSafety.contentSafetyStatus = "Disabled";
        modelSettings.modelId = "azureml://registries/azureml-deepseek/models/DeepSeek-R1";
      };

      sku.name = "Consumption";
    };
  };
}
