{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "vllm";
  cfg = config.codgician.services.vllm;
  types = lib.types;
  instanceNames = builtins.attrNames cfg.instances;

  # Make config for systemd service
  mkSystemdConfig =
    instance:
    let
      instanceCfg = cfg.instances.${instance};
    in
    {
      "vllm@${instance}" = {
        # Systemd service for vLLM
        enable = true;
        restartIfChanged = true;
        description = "vLLM instance: ${instance}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = instanceCfg.environmentVariables;

        serviceConfig = {
          ExecStart = builtins.concatStringsSep " " (
            [
              (lib.getExe cfg.package)
              "serve ${instanceCfg.model}"
              "--host ${instanceCfg.host}"
              "--port ${builtins.toString instanceCfg.port}"
              "--download-dir ${cfg.downloadDir}"
            ]
            ++ instanceCfg.extraArgs
          );

          WorkingDirectory = "/var/lib/vllm";
          StateDirectory = "vllm";
          RuntimeDirectory = "vllm";
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
    };

  # Make configs for nginx reverse proxy
  mkReverseProxyConfig =
    instance:
    lib.codgician.mkServiceReverseProxyConfig {
      serviceName = "${serviceName}@${instance}";
      cfg = cfg.instances.${instance};
    };
in
{
  options.codgician.services.vllm = {
    enable = lib.mkEnableOption "vLLM.";

    package = lib.mkPackageOption pkgs "vllm" { };

    instances = lib.mkOption {
      type =
        with types;
        attrsOf (
          submodule (
            { config, ... }:
            {
              options = {
                host = lib.mkOption {
                  type = types.str;
                  default = "127.0.0.1";
                  description = ''
                    Host for vLLM to listen on.
                  '';
                };

                port = lib.mkOption {
                  type = types.port;
                  default = 8000;
                  description = ''
                    Port for vLLM to listen on.
                  '';
                };

                model = lib.mkOption {
                  type = types.str;
                  description = "Model for vLLM to serve.";
                  example = "deepseek-ai/DeepSeek-R1-Distill-Qwen-32B";
                };

                environmentVariables = lib.mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                  description = "Environment variables for vLLM.";
                  example = {
                    VLLM_ATTENTION_BACKEND = "FLASH_ATTN";
                    VLLM_FLASH_ATTN_VERSION = "3";
                  };
                };

                extraArgs = lib.mkOption {
                  type = with types; listOf str;
                  description = "Additional args passed to vLLM serve.";
                  default = [ ];
                  example = [
                    "--enable-reasoning"
                    "--reasoning-parser deepseek_r1"
                  ];
                };

                # Reverse proxy profile for nginx
                reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
                  inherit serviceName;
                  defaultProxyPass = "http://${config.host}:${builtins.toString config.port}";
                  defaultProxyPassText = ''with config.codgician.services.vllm.instances.*; http://$\{host}:$\{builtins.toString port}'';
                };
              };
            }
          )
        );
      default = { };
      description = "vLLM instances.";
    };

    downloadDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/vllm-cache";
      description = "Directory for vllm to download weights.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mkMerge (builtins.map mkSystemdConfig instanceNames);
    codgician.services.nginx = lib.mkMerge (builtins.map mkReverseProxyConfig instanceNames);
  };
}
