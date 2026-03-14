{
  config,
  lib,
  ...
}:
let
  serviceName = "mirofish";
  inherit (lib) types;
  cfg = config.codgician.services.${serviceName};
  defaultDataDir = "/var/lib/${serviceName}";
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "MiroFish - Swarm Intelligence Prediction Engine";

    backend = lib.mkOption {
      type = types.enum [ "container" ];
      default = "container";
      description = "Backend to use for deploying ${serviceName}.";
    };

    image = lib.mkOption {
      type = types.str;
      default = "ghcr.io/666ghj/mirofish:latest";
      description = "Container image for ${serviceName}.";
    };

    frontendPort = lib.mkOption {
      type = types.port;
      default = 3000;
      description = "Port for ${serviceName} frontend to listen on.";
    };

    backendPort = lib.mkOption {
      type = types.port;
      default = 5001;
      description = "Port for ${serviceName} backend API to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = defaultDataDir;
      description = "Data directory for ${serviceName} uploads and state.";
    };

    environment = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional environment variables for ${serviceName}.";
    };

    # Reverse proxy profile for nginx (frontend)
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.frontendPort}";
      defaultProxyPassText = "with config.codgician.services.${serviceName}; http://127.0.0.1:\${toString frontendPort}";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.backend == "container") {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = cfg.image;

        ports = [
          "${toString cfg.frontendPort}:3000"
          "${toString cfg.backendPort}:5001"
        ];

        volumes = [
          "${cfg.dataDir}/uploads:/app/backend/uploads:U"
        ];

        environment = {
          # Allow reverse proxy domains in Vite
          __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS = lib.concatStringsSep "," cfg.reverseProxy.domains;
        }
        // cfg.environment;

        environmentFiles = [ config.age.secrets.mirofish-env.path ];

        extraOptions = [
          "--pull=newer"
        ];
      };

      # Ensure data directories exist
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/uploads 0755 root root -"
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
