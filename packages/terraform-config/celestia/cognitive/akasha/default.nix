{ config, ... }:
let
  location = "swedencentral";
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  inherit (config.provider.azurerm) tenant_id client_id;
in
{
  imports = [
    ./deepseek-v4-flash.nix
    ./flux.2-pro.nix
    ./gpt-4o-transcribe-diarize.nix
    ./gpt-5.4-nano.nix
    ./gpt-5.4-pro.nix
    ./gpt-image-2.nix
    ./gpt-audio-1.5.nix
    ./gpt-realtime-1.5.nix
    ./grok-4-20.nix
    ./kimi-k2.6.nix
  ];

  resource = {
    azurerm_ai_services.akasha = rec {
      name = "akasha";
      custom_subdomain_name = name;
      public_network_access = "Enabled";
      inherit location resource_group_name;
      sku_name = "S0";
    };

    azurerm_key_vault.akasha-keyvault = {
      name = "akasha-keyvault";
      inherit location resource_group_name tenant_id;
      sku_name = "standard";
      purge_protection_enabled = true;
    };

    azurerm_key_vault_access_policy.akasha-keyvault-policy = {
      key_vault_id = config.resource.azurerm_key_vault.akasha-keyvault "id";
      inherit tenant_id;
      object_id = client_id;
      key_permissions = [
        "Create"
        "Get"
        "Delete"
        "Purge"
        "GetRotationPolicy"
      ];
    };

    azurerm_storage_account.akashastorage = {
      name = "akashastorage";
      inherit location resource_group_name;
      account_tier = "Standard";
      account_replication_type = "LRS";
    };

    azurerm_ai_foundry.akasha = {
      name = "akasha";
      inherit location resource_group_name;
      storage_account_id = config.resource.azurerm_storage_account.akashastorage "id";
      key_vault_id = config.resource.azurerm_key_vault.akasha-keyvault "id";
      identity.type = "SystemAssigned";
    };

    azurerm_ai_foundry_project.akasha-ai-project = {
      name = "akasha-ai-project";
      inherit location;
      ai_services_hub_id = config.resource.azurerm_ai_foundry.akasha "id";
      identity.type = "SystemAssigned";
    };
  };
}
