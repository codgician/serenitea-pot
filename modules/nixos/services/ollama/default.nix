{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.ollama;
  types = lib.types;
in
{
  options.codgician.services.ollama = {
    enable = lib.mkEnableOption "Ollama.";

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
      type = types.path;
      default = "/var/lib/ollama";
      description = "Directory for ollama to store data.";
    };

    modelDir = lib.mkOption {
      type = types.path;
      default = "${cfg.dataDir}/models";
      description = "Directory for ollama to store models.";
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

    acceleration = lib.mkOption {
      type = types.nullOr (
        types.enum [
          false
          "cuda"
          "rocm"
        ]
      );
      default = null;
      description = "Acceleration backend for ollama.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for ollama.";

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
        inherit (cfg)
          host
          port
          loadModels
          user
          group
          acceleration
          ;
        home = cfg.dataDir;
        models = cfg.modelDir;
        environmentVariables = {
          OLLAMA_FLASH_ATTENTION = lib.mkIf (cfg.acceleration != false) "1";
          OLLAMA_KV_CACHE_TYPE = "q8_0";
          # Increase default context length to 8K
          OLLAMA_CONTEXT_LENGTH = "8192";
        };

        # Override package to save build time
        package =
          if cfg.acceleration == "rocm" then
            pkgs.ollama-rocm
          else if cfg.acceleration == "cuda" then
            pkgs.ollama-cuda
          else
            pkgs.ollama;
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
