{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "matrix-tuwunel";
  serviceUser = "tuwunel"; # Match upstream NixOS module
  cfg = config.codgician.services.matrix-tuwunel;
  types = lib.types;
  inherit (lib.codgician) published;
  svc = published.services.matrix-tuwunel;
  vhost = config.codgician.services.nginx.reverseProxies.matrix-tuwunel;

  # Unix socket path
  socketPath = "/run/tuwunel/tuwunel.sock";
in
{
  options.codgician.services.matrix-tuwunel = {
    dataPath = lib.mkOption {
      type = types.str;
      default = "/var/lib/tuwunel";
      description = "Path where Tuwunel server stores its data (RocksDB database and media).";
    };

    zfsOptimizations = lib.mkEnableOption "RocksDB optimizations for ZFS (disables direct I/O, uses zstd compression).";
  };

  config = lib.mkMerge [
    (lib.mkIf (svc.host == config.networking.hostName) {
      services.matrix-tuwunel = {
        enable = true;
        settings.global = {
          # Core settings
          server_name = svc.domain;
          # database_path defaults to /var/lib/tuwunel, BindPaths redirects to cfg.dataPath
          # Use unix socket instead of TCP (more efficient, more secure)
          unix_socket_path = socketPath;
          unix_socket_perms = 660;

          # Registration disabled - SSO/OIDC users are auto-provisioned on first login
          allow_registration = false;

          # Federation
          allow_federation = true;
          trusted_servers = [
            "matrix.org"
            "libera.chat"
            "nixos.org"
          ];

          # Max request size (24MB)
          max_request_size = 25165824;

          # TURN configuration (hardcoded to turn.codgician.me)
          turn_uris = [
            "turn:turn.codgician.me?transport=udp"
            "turn:turn.codgician.me?transport=tcp"
            "turns:turn.codgician.me:5349?transport=tcp"
          ];
          turn_secret_file = config.codgician.secrets.files.coturn-auth-secret.path;
          turn_ttl = 86400;
        }
        // lib.optionalAttrs cfg.zfsOptimizations {
          # Disable direct I/O for ZFS compatibility
          rocksdb_direct_io = false;
          rocksdb_compression_algo = "zstd";
        }
        // {
          # SSO/OIDC configuration for Authelia
          identity_provider = [
            {
              brand = "authelia";
              client_id = serviceName;
              client_secret_file = config.codgician.secrets.files.tuwunel-oidc-secret-authelia-main.path;
              issuer_url = published.autheliaUrl;
              callback_url = "https://${svc.domain}/_matrix/client/unstable/login/sso/callback/${serviceName}";
              default = true;
              name = "Authelia";
              scope = [
                "openid"
                "offline_access"
                "profile"
                "email"
                "groups"
              ];
            }
          ];
        };
      };

      # Override systemd service for custom data path
      systemd.services.tuwunel.serviceConfig = {
        BindPaths = lib.mkIf (cfg.dataPath != "/var/lib/tuwunel") [
          "${cfg.dataPath}:/var/lib/tuwunel"
        ];
        # Use static user for agenix secret ownership
        DynamicUser = lib.mkForce false;
      };

      # Create static user and group (required for agenix secrets)
      users.users.tuwunel = {
        group = "tuwunel";
        isSystemUser = true;
      };
      users.groups.tuwunel.members = [ "nginx" ];

      # sops secrets
      codgician.secrets.files = {
        tuwunel-oidc-secret-authelia-main = {
          owner = serviceUser;
          group = serviceUser;
          mode = "0600";
        };
        coturn-auth-secret = {
          owner = serviceUser;
          group = serviceUser;
          mode = "0600";
        };
      };

      # Ensure data directory exists with correct permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.dataPath} 0700 ${serviceUser} ${serviceUser} -"
      ];

      # Persist data directory if using impermanence (only for default path)
      codgician.system.impermanence.extraItems = lib.optional (cfg.dataPath == "/var/lib/tuwunel") {
        type = "directory";
        path = cfg.dataPath;
        user = serviceUser;
        group = serviceUser;
      };
    })

    # The vhost serves Element at `/` and the well-known documents itself, on
    # the backend host and on the edge alike.
    {
      codgician.services.nginx.reverseProxies.matrix-tuwunel =
        let
          clientConfig = {
            "m.homeserver".base_url = "https://${svc.domain}";
            "org.matrix.msc3575.proxy".url = "https://${svc.domain}"; # Sliding sync
          };
          serverConfig = {
            "m.server" = "${svc.domain}:443";
          };
        in
        {
          proxyPass = lib.mkDefault "http://unix:${socketPath}";
          locations = {
            "/" = {
              proxyPass = lib.mkForce null;
              root = import ./element-web.nix {
                inherit pkgs clientConfig;
                domains = [ svc.domain ];
              };
            };

            # Matrix C-S and S-S API endpoints
            "~ ^/_matrix/" = {
              inherit (vhost) proxyPass;
              extraConfig = ''
                # Allow large media uploads (0 = unlimited)
                client_max_body_size 0;

                # Matrix sync can be long-polling
                proxy_read_timeout 300;
              '';
            };

            # Tuwunel-specific endpoints (health check, version, admin)
            "~ ^/_conduwuit/" = {
              inherit (vhost) proxyPass;
            };

            # Well-known endpoints for federation and client discovery
            "= /.well-known/matrix/server" = {
              return = "200 '${builtins.toJSON serverConfig}' ";
              extraConfig = ''
                add_header Content-Type application/json;
                add_header Access-Control-Allow-Origin *;
              '';
            };

            "= /.well-known/matrix/client" = {
              return = "200 '${builtins.toJSON clientConfig}' ";
              extraConfig = ''
                add_header Content-Type application/json;
                add_header Access-Control-Allow-Origin *;
              '';
            };
          };
        };
    }
  ];
}
