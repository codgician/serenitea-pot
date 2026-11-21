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
  inherit (cfg) domain;

  # Unix socket path
  socketPath = "/run/tuwunel/tuwunel.sock";
in
{
  options.codgician.services.matrix-tuwunel = {
    enable = lib.mkEnableOption "Tuwunel Matrix homeserver";
    package = lib.mkPackageOption pkgs "matrix-tuwunel" { };
    elementWebPackage = lib.mkPackageOption pkgs "element-web" {
      extraDescription = "It is the client served at the homeserver's domain.";
    };

    domain = lib.mkOption {
      type = types.str;
      default = "matrix.${lib.codgician.zone}";
      defaultText = lib.literalExpression ''"matrix.''${lib.codgician.zone}"'';
      example = "matrix.example.org";
      description = "Domain name for the Tuwunel server (server_name).";
    };

    elementWeb = lib.mkEnableOption ''
      Host Element web client at `/`.
    '';

    dataPath = lib.mkOption {
      type = types.str;
      default = "/var/lib/tuwunel";
      description = "Path where Tuwunel server stores its data (RocksDB database and media).";
    };

    zfsOptimizations = lib.mkEnableOption "RocksDB optimizations for ZFS (disables direct I/O, uses zstd compression).";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.matrix-tuwunel.proxyPass = "http://unix:${socketPath}";

      services.matrix-tuwunel = {
        enable = true;
        inherit (cfg) package;
        settings.global = {
          # Core settings
          server_name = domain;
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

          # TURN server run by the coturn module
          turn_uris =
            let
              turn = config.codgician.services.coturn.domain;
            in
            [
              "turn:${turn}?transport=udp"
              "turn:${turn}?transport=tcp"
              "turns:${turn}:5349?transport=tcp"
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
              issuer_url = config.codgician.services.authelia.instances.main.url;
              callback_url = "https://${domain}/_matrix/client/unstable/login/sso/callback/${serviceName}";
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

    # The site serves the well-known documents itself, and Element at `/`
    # if enabled, on every host that proxies it.
    {
      codgician.services.nginx.reverseProxies.matrix-tuwunel.domains = [ domain ];
      codgician.services.nginx.reverseProxies.matrix-tuwunel.locations =
        let
          clientConfig = {
            "m.homeserver".base_url = "https://${domain}";
            "org.matrix.msc3575.proxy".url = "https://${domain}"; # Sliding sync
          };
          serverConfig = {
            "m.server" = "${domain}:443";
          };
        in
        {
          "/" = lib.mkIf cfg.elementWeb {
            root = import ./element-web.nix {
              inherit pkgs clientConfig;
              element-web = cfg.elementWebPackage;
              domains = [ domain ];
            };
          };

          # Matrix C-S and S-S API endpoints
          "~ ^/_matrix/".extraConfig = ''
            # Allow large media uploads (0 = unlimited)
            client_max_body_size 0;

            # Matrix sync can be long-polling
            proxy_read_timeout 300;
          '';

          # Tuwunel-specific endpoints (health check, version, admin)
          "~ ^/_conduwuit/" = { };

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
    }
  ];
}
