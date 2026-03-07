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

  # Unix socket path
  socketPath = "/run/tuwunel/tuwunel.sock";

  # Authelia OIDC config
  autheliaInstance = "main";
  autheliaSessionDomain =
    config.codgician.services.authelia.instances.${autheliaInstance}.sessionDomain;
  autheliaUrl = "https://auth.${autheliaSessionDomain}";
in
{
  options.codgician.services.matrix-tuwunel = {
    enable = lib.mkEnableOption "Tuwunel Matrix server.";

    domain = lib.mkOption {
      type = types.str;
      example = "matrix.example.org";
      description = "Domain name for the Tuwunel server (server_name).";
    };

    dataPath = lib.mkOption {
      type = types.str;
      default = "/var/lib/tuwunel";
      description = "Path where Tuwunel server stores its data (RocksDB database and media).";
    };

    zfsOptimizations = lib.mkEnableOption "RocksDB optimizations for ZFS (disables direct I/O, uses zstd compression).";

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultDomains = [ cfg.domain ];
      defaultDomainsText = "[ config.codgician.services.matrix-tuwunel.domain ]";
      defaultProxyPass = "http://unix:${socketPath}";
      defaultProxyPassText = "http://unix:/run/tuwunel/tuwunel.sock";
      extraOptions = {
        elementWeb = lib.mkEnableOption ''
          Host Element web client at `/`.
        '';
      };
    };
  };

  config = lib.mkMerge [
    # Tuwunel service configuration (only when service is enabled locally)
    (lib.mkIf cfg.enable {
      services.matrix-tuwunel = {
        enable = true;
        settings.global = {
          # Core settings
          server_name = cfg.domain;
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
          ];
          turn_secret_file = config.age.secrets.tuwunel-turn-secret.path;
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
              client_secret_file = config.age.secrets.tuwunel-oidc-secret-authelia-main.path;
              issuer_url = autheliaUrl;
              callback_url = "https://${cfg.domain}/_matrix/client/unstable/login/sso/callback/${serviceName}";
              default = true;
              name = "Authelia";
              scope = [
                "openid"
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

      # Agenix secrets
      codgician.system.agenix.secrets = {
        tuwunel-oidc-secret-authelia-main = {
          owner = serviceUser;
          group = serviceUser;
          mode = "0600";
        };
        tuwunel-turn-secret = {
          owner = serviceUser;
          group = serviceUser;
          mode = "0600";
        };
      };

      # Ensure data directory exists with correct permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.dataPath} 0700 ${serviceUser} ${serviceUser} -"
      ];

      # Persist data directory if using impermanence
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = cfg.dataPath;
          user = serviceUser;
          group = serviceUser;
        }
      ];
    })

    # Reverse proxy profile (can be enabled independently for external proxies)
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
        extraVhostConfig =
          let
            clientConfig = {
              "m.homeserver".base_url = "https://${cfg.domain}";
              "org.matrix.msc3575.proxy".url = "https://${cfg.domain}"; # Sliding sync
            };
            serverConfig = {
              "m.server" = "${cfg.domain}:443";
            };
          in
          {
            locations = {
              "/" = lib.mkIf cfg.reverseProxy.elementWeb {
                passthru = {
                  proxyPass = lib.mkForce null;
                  root = import ./element-web.nix {
                    inherit pkgs clientConfig;
                    domains = cfg.reverseProxy.domains;
                  };
                };
              };

              # Matrix C-S and S-S API endpoints
              "~ ^/_matrix/" = {
                inherit (cfg.reverseProxy) lanOnly;
                passthru = {
                  inherit (cfg.reverseProxy) proxyPass;
                  extraConfig = ''
                    # Allow large media uploads (0 = unlimited)
                    client_max_body_size 0;

                    # Matrix sync can be long-polling
                    proxy_read_timeout 300;
                  '';
                };
              };

              # Tuwunel-specific endpoints (health check, version, admin)
              "~ ^/_conduwuit/" = {
                inherit (cfg.reverseProxy) lanOnly;
                passthru = {
                  inherit (cfg.reverseProxy) proxyPass;
                };
              };

              # Well-known endpoints for federation and client discovery
              "= /.well-known/matrix/server" = {
                inherit (cfg.reverseProxy) lanOnly;
                passthru = {
                  return = "200 '${builtins.toJSON serverConfig}' ";
                  extraConfig = ''
                    add_header Content-Type application/json;
                    add_header Access-Control-Allow-Origin *;
                  '';
                };
              };

              "= /.well-known/matrix/client" = {
                inherit (cfg.reverseProxy) lanOnly;
                passthru = {
                  return = "200 '${builtins.toJSON clientConfig}' ";
                  extraConfig = ''
                    add_header Content-Type application/json;
                    add_header Access-Control-Allow-Origin *;
                  '';
                };
              };
            };
          };
      };
    }
  ];
}
