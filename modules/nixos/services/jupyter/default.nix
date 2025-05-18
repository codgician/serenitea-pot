{ config, lib, ... }:
let
  serviceName = "jupyter";
  cfg = config.codgician.services.jupyter;
  types = lib.types;
in
{
  imports = [ ./kernels ];

  options.codgician.services.jupyter = {
    enable = lib.mkEnableOption "Jupyter";

    ip = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for Jupyter to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8888;
      description = "Port for Jupyter to listen on.";
    };

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "User under which Jupyter runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Jupyter runs.";
    };

    notebookDir = lib.mkOption {
      type = types.str;
      default = "~/";
      description = "Root directory for notebooks.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.ip}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.jupyter; http://$\{ip}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    # Jupyter configurations
    (lib.mkIf cfg.enable {
      services.jupyter = {
        enable = true;
        inherit (cfg)
          ip
          port
          user
          group
          notebookDir
          ;
        # Use auth token
        password = "";
        notebookConfig = lib.optionalString cfg.reverseProxy.enable ''
          c.ServerApp.allow_remote_access = True
        '';
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
