{
  config,
  lib,
  ...
}:
let
  serviceName = "open-terminal";
  inherit (lib) types;
  cfg = config.codgician.services.open-terminal;
  defaultDataDir = "/var/lib/open-terminal";
in
{
  options.codgician.services.open-terminal = {
    enable = lib.mkEnableOption "open-terminal container";

    port = lib.mkOption {
      type = types.port;
      default = 8000;
      description = "Port for open-terminal to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = defaultDataDir;
      description = "Data directory for open-terminal.";
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
        ports = [ "127.0.0.1:${builtins.toString cfg.port}:8000" ];
        volumes = [
          "${cfg.dataDir}:/home/user:U"
        ];
        environmentFiles = [ config.age.secrets.open-terminal-env.path ];
        extraOptions = [ "--pull=newer" ];
      };

      virtualisation.podman.enable = true;

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
