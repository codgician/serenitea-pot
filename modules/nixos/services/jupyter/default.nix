{ config, lib, ... }:
let
  cfg = config.codgician.services.jupyter;
  types = lib.types;
in
{
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
      default = "jupyter";
      description = "User under which Jupyter runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "jupyter";
      description = "Group under which Jupyter runs.";
    };

    notebookDir = lib.mkOption {
      type = types.str;
      default = "~/";
      description = "Root directory for notebooks.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for Jupyter.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = "List of domains for the reverse proxy.";
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://${cfg.ip}:${builtins.toString cfg.port}";
        description = "Source URI for the reverse proxy.";
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
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
      };
    })

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.jupyter = {
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
