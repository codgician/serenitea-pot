{ config, lib, pkgs, outputs,... }:
let
  cfg = config.codgician.services.litellm;
  types = lib.types;

  terraformConf = builtins.fromJSON outputs.packages.${pkgs.system}.terraformConfiguration.value;
  azureApiBase = "https://${terraformConf.resource.azurerm_cognitive_account.akasha.name}.openai.azure.com";
  azureModels = builtins.map (x: {
    model_name = x.name;
    litellm_params = {
      model = "azure/${x.name}";
      api_base = azureApiBase;
      api_key = "os.environ/AZURE_AKASHA_API_KEY";
      rpm = 6;
    };
  }) (builtins.attrValues terraformConf.resource.azurerm_cognitive_deployment);

  settingsFormat = pkgs.formats.yaml { };
  settings.model_list = azureModels;
in
{
  options.codgician.services.litellm = {
    enable = lib.mkEnableOption "Enable LiteLLM Proxy.";

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

    package = lib.mkPackageOption pkgs.python3Packages "litellm" { };

    dataDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/litellm";
      description = ''
        Directory for LiteLLM to store data.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = "litellm";
      description = "User under which LiteLLM runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "litellm";
      description = "Group under which LiteLLM runs.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for LiteLLM.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.com" "example.org" ];
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

  config = let
    litellmProxyPkg = cfg.package.overridePythonAttrs (prev: {
      dependencies = prev.dependencies ++ cfg.package.optional-dependencies.proxy;
    });
  in lib.mkMerge [
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
            ${litellmProxyPkg}/bin/litellm \
              --config ${settingsFormat.generate "litellm-config.yml" settings} \
              --host ${cfg.host} \
              --port ${builtins.toString cfg.port} \
              --telemetry False
          '';

          EnvironmentFile = config.age.secrets.litellmEnv.path;
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

    (lib.mkIf cfg.enable
      (lib.codgician.mkAgenixConfigs "root" [ (lib.codgician.secretsDir + "/litellmEnv.age") ]))

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
