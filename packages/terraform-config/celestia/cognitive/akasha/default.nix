{ config, ... }:
let
  location = "eastus2";
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  inherit (config.provider.azurerm) tenant_id client_id;
in
{
  imports = [
    ./deepseek-r1.nix
    ./deepseek-v3.nix
    ./gpt-4o.nix
    ./gpt-4o-realtime.nix
    ./o3-mini.nix
  ];

  resource = {
    azurerm_ai_services.akasha = rec {
      name = "akasha";
      custom_subdomain_name = name;
      public_network_access = "Enabled";
      inherit location resource_group_name;
      sku_name = "S0";
    };

    azurerm_key_vault.akasha-kv = {
      name = "akasha-kv";
      inherit location resource_group_name tenant_id;
      sku_name = "standard";
      purge_protection_enabled = true;
    };

    azurerm_key_vault_access_policy.akasha-kvpolicy = {
      key_vault_id = config.resource.azurerm_key_vault.akasha-kv "id";
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
      key_vault_id = config.resource.azurerm_key_vault.akasha-kv "id";
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
