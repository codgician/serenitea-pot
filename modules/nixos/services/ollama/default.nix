{ config, lib, ... }:
let
  cfg = config.codgician.services.ollama;
  types = lib.types;
in
{
  options.codgician.services.ollama = {
    enable = lib.mkEnableOption "Enable Ollama.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for ollama to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 11434;
      description = ''
        Port for ollama to listen on.
      '';
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/ollama";
      description = ''
        Directory for ollama to store data.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = "ollama";
      description = "User under which ollama runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "ollama";
      description = "Group under which ollama runs.";
    };

    loadModels = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Download these models using `ollama pull` as soon as ollama.service has started.
        Search for models of your choice from: https://ollama.com/library
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for ollama.";

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
        defaultText = ''http://$\{config.codgician.services.ollama.host\}:$\{toString config.codgician.services.ollama.port\}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        inherit (cfg) host port loadModels user group;
        home = cfg.dataDir;
        models = "${cfg.dataDir}/models";
      };
    })

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