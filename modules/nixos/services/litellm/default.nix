{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
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
      };
    }))
  ];

  settingsFormat = pkgs.formats.yaml { };
  settings.model_list = azureModels ++ [
    {
      model_name = "gemini-2.5-pro";
      litellm_params = {
        model = "gemini/gemini-2.5-pro-exp-03-25";
        api_key = "os.environ/GEMINI_API_KEY";
      };
    }
    {
      model_name = "gemini-2.0-flash";
      litellm_params = {
        model = "gemini/gemini-2.0-flash";
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

    dataDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/litellm";
      description = ''
        Directory for LiteLLM to store data.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for LiteLLM.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://${cfg.host}:${builtins.toString cfg.port}";
        defaultText = ''http://$\{config.codgician.services.litellm.host\}:$\{toString config.codgician.services.litellm.port\}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Systemd service for LiteLLM
      systemd.services.litellm = lib.optionalAttrs cfg.enable {
        inherit (cfg) enable;
        restartIfChanged = true;
        description = "LiteLLM proxy service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = ''
            ${lib.getExe cfg.package} \
              --config ${settingsFormat.generate "litellm-config.yml" settings} \
              --host ${cfg.host} \
              --port ${builtins.toString cfg.port} \
              --telemetry False
          '';

          EnvironmentFile = config.age.secrets.litellm-env.path;
          WorkingDirectory = cfg.dataDir;
          StateDirectory = "litellm";
          RuntimeDirectory = "litellm";
          RuntimeDirectoryMode = "0755";
          PrivateTmp = true;
          DynamicUser = true;
          DevicePolicy = "closed";
          LockPersonality = true;
          PrivateUsers = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };
    })

    (lib.mkIf cfg.enable (
      with lib.codgician; mkAgenixConfigs { } [ (getAgeSecretPathFromName "litellm-env") ]
    ))

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.ollama = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };
    })
  ];
}
