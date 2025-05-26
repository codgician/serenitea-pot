{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  serviceName = "litellm";
  cfg = config.codgician.services.litellm;
  types = lib.types;

  terraformConf = builtins.fromJSON outputs.packages.${pkgs.system}.terraform-config.value;
  azureSubdomain = terraformConf.resource.azurerm_ai_services.akasha.custom_subdomain_name;
  azureModels = lib.pipe terraformConf.resource.azurerm_cognitive_deployment [
    builtins.attrValues
    (builtins.map (x: {
      model_name = x.name;
      litellm_params = {
        model = "azure_ai/${x.name}";
        api_base = "https://${azureSubdomain}.cognitiveservices.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
        api_version = "2025-04-01-preview";
      };
    }))
  ];

  allModels = azureModels ++ [
    {
      model_name = "grok-3";
      litellm_params = {
        model = "azure_ai/grok-3";
        api_base = "https://${azureSubdomain}.services.ai.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
      };
    }
    {
      model_name = "gemini-2.5-pro";
      litellm_params = {
        model = "gemini/gemini-2.5-pro-preview-05-06";
        api_key = "os.environ/GEMINI_API_KEY";
      };
    }
    {
      model_name = "gemini-2.5-flash";
      litellm_params = {
        model = "gemini/gemini-2.5-flash-preview-05-20";
        api_key = "os.environ/GEMINI_API_KEY";
      };
    }
    {
      model_name = "akasha-deepseek-r1";
      litellm_params = {
        model = "azure_ai/akasha-deepseek-r1";
        api_base = "os.environ/AZURE_AKASHA_DEEPSEEK_R1_API_BASE";
        api_key = "os.environ/AZURE_AKASHA_DEEPSEEK_R1_API_KEY";
      };
    }
    {
      model_name = "akasha-deepseek-v3";
      litellm_params = {
        model = "azure_ai/akasha-deepseek-v3";
        api_base = "os.environ/AZURE_AKASHA_DEEPSEEK_V3_API_BASE";
        api_key = "os.environ/AZURE_AKASHA_DEEPSEEK_V3_API_KEY";
      };
    }
  ];
in
{
  options.codgician.services.litellm = {
    enable = lib.mkEnableOption "LiteLLM Proxy.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for LiteLLM to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 5483;
      description = ''
        Port for LiteLLM to listen on.
      '';
    };

    package = lib.mkPackageOption pkgs "litellm" { };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/litellm";
      description = ''
        Directory for LiteLLM to store state data.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.litellm; http://$\{host}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.litellm = {
        enable = true;
        inherit (cfg) host port stateDir;
        environmentFile = config.age.secrets.litellm-env.path;
        settings.model_list = allModels;
      };
    })

    (lib.mkIf cfg.enable (
      with lib.codgician; mkAgenixConfigs { } [ (getAgeSecretPathFromName "litellm-env") ]
    ))

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
