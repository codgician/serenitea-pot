{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  serviceName = "open-terminal";
  inherit (lib) types;
  cfg = config.codgician.services.open-terminal;
  defaultDataDir = "/var/lib/open-terminal";

  # TOML format for settings type
  tomlFormat = pkgs.formats.toml { };

  # Configuration with ._secret for API key
  settings = {
    host = cfg.host;
    port = cfg.port;
    api_key._secret = config.age.secrets.open-terminal-api-key.path;
  }
  // cfg.settings;
in
{
  options.codgician.services.open-terminal = {
    enable = lib.mkEnableOption "open-terminal container";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for open-terminal to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8022;
      description = "Port for open-terminal to listen on.";
    };

    openFirewall = lib.mkEnableOption "opening firewall for ${serviceName}";

    dataDir = lib.mkOption {
      type = types.path;
      default = defaultDataDir;
      description = "Data directory for open-terminal.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {
        multi_user = true;
      };
      example = lib.literalExpression ''
        {
          multi_user = true;
          cors_allowed_origins = "*";
          max_terminal_sessions = 16;
          execute_timeout = 30;
        }
      '';
      description = ''
        Additional settings for open-terminal config.toml.
        See https://github.com/open-webui/open-terminal for available options.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.open-terminal; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.open-terminal = {
        autoStart = true;
        image = "ghcr.io/open-webui/open-terminal:latest";
        ports = [ "${cfg.host}:${builtins.toString cfg.port}:${builtins.toString cfg.port}" ];
        volumes = [
          "${cfg.dataDir}:/home/user:U"
          "/run/${serviceName}/config.toml:/etc/open-terminal/config.toml:ro"
        ];
        extraOptions = [ "--pull=newer" ];
      };

      virtualisation.podman.enable = true;

      # Generate config.toml with secrets replacement before container starts
      systemd.services.podman-open-terminal = {
        preStart = lib.mkBefore ''
          ${utils.genJqSecretsReplacementSnippet settings "/run/${serviceName}/config.json"}
          ${lib.getExe pkgs.yj} -jt < /run/${serviceName}/config.json > /run/${serviceName}/config.toml
          rm /run/${serviceName}/config.json
        '';
        serviceConfig.RuntimeDirectory = serviceName;
      };

      # Open firewall if requested
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

      # Ensure data directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != defaultDataDir) [
        "d ${cfg.dataDir} 0755 root root -"
      ];

      # Persist data directory (only when using default location)
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
        {
          type = "directory";
          path = cfg.dataDir;
        }
      ];
    })

    # Reverse proxy profile
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      };
    }
  ];
}
