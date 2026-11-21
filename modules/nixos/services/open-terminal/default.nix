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

  tomlFormat = pkgs.formats.toml { };

  # The container keeps its defaults (0.0.0.0:8000); only the host port is remapped
  settings = {
    api_key._secret = config.codgician.secrets.files.open-terminal-api-key.path;
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

    image = lib.mkOption {
      type = types.str;
      default = "ghcr.io/open-webui/open-terminal:latest";
      description = "Container image for open-terminal.";
    };

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
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.open-terminal = {
      autoStart = true;
      inherit (cfg) image;
      ports = [ "${cfg.host}:${toString cfg.port}:8000" ];
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
  };
}
