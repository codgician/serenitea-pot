{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "dendrite";
  cfg = config.codgician.services.dendrite;
  types = lib.types;

  dbHost = "/run/postgresql";
  dbName = serviceName;
  database = {
    connection_string = "postgres:///${dbName}?host=${dbHost}";
    max_open_conns = 80;
    max_idle_conns = 5;
    conn_max_lifetime = -1;
  };
in
{
  options.codgician.services.dendrite = {
    enable = lib.mkEnableOption "Dendrite Matrix server.";

    httpPort = lib.mkOption {
      type = types.port;
      default = 8008;
      description = "Port for Dendrite server to listen HTTP requests on.";
    };

    dataPath = lib.mkOption {
      type = types.str;
      default = "/var/lib/dendrite";
      description = "Path where Dendrite server store its data.";
    };

    domain = lib.mkOption {
      type = types.str;
      example = "matrix.example.org";
      description = "Domain name for the Dendrite server.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultDomains = [ cfg.domain ];
      defaultDomainsText = "[ config.codgician.services.dendrite.domain ]";
      defaultProxyPass = "http://127.0.0.1:${builtins.toString cfg.httpPort}";
      defaultProxyPassText = ''with config.codgician.services.dendrite; http://127.0.0.1:$\{builtins.toString httpPort}'';
      extraOptions = {
        proxyAll = lib.mkEnableOption ''
          Proxy everything under `/`.
          Otherwise, only `/_matrix` and `/_synapse` will be proxied.
        '';
        elementWeb = lib.mkEnableOption ''
          Host Element web client at `/`.
          To enable this option, `codgician.services.dendrite.reverseProxy.proxyAll` must be disabled.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Dendrite
      services.dendrite = {
        enable = true;
        inherit (cfg) httpPort;
        openRegistration = false;
        environmentFile = config.age.secrets.matrix-env.path;
        settings = {
          global = {
            server_name = cfg.domain;
            private_key = "$CREDENTIALS_DIRECTORY/private_key";
            jetstream.storage_path = "${cfg.dataPath}/jetstream";
            trusted_third_party_id_servers = [
              "matrix.codgician.me"
              "matrix.org"
              "libera.chat"
              "nixos.org"
              "gitter.im"
              "vector.im"
            ];

            # metrics.enabled = true;
          };

          logging = [
            {
              type = "std";
              level = "warn";
            }
          ];

          app_service_api = {
            inherit database;
          };

          media_api = {
            inherit database;
            base_path = "${cfg.dataPath}/media_store";
            dynamic_thumbnails = true;
          };

          key_server = {
            inherit database;
          };

          mscs = {
            inherit database;
            mscs = [
              "msc2836" # threads
              "msc2946" # space summaries
            ];
          };

          client_api = {
            registration_disabled = false;
            recaptcha_public_key = "6LfaZzopAAAAABF3bgWvpyacT6RKllDzRJgkJqaA";
            recaptcha_private_key = "$RECAPTCHA_PRIVATE_KEY";
            enable_registration_captcha = true;
            recaptcha_siteverify_api = "https://www.google.com/recaptcha/api/siteverify";
            recaptcha_api_js_url = "https://www.recaptcha.net/recaptcha/api.js";

            turn = {
              turn_user_lifetime = "5m";
              turn_uris = [
                "turn:turn.codgician.me?transport=udp"
                "turn:turn.codgician.me?transport=tcp"
              ];
              turn_shared_secret = "$TURN_SHARED_SECRET";
            };
          };

          relay_api = { inherit database; };
          room_server = { inherit database; };
          push_server = { inherit database; };
          sync_api = {
            inherit database;
            real_ip_header = "X-Real-IP";
            search = {
              enabled = true;
              index_path = "${cfg.dataPath}/searchindex";
              language = "cjk";
            };
          };
          user_api = {
            account_database = database;
            device_database = database;
          };
          federation_api = {
            inherit database;
            key_perspectives = [
              {
                server_name = "matrix.org";
                keys = [
                  {
                    key_id = "ed25519:auto";
                    public_key = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
                  }
                  {
                    key_id = "ed25519:a_RXGa";
                    public_key = "l8Hft5qXKn1vfHrg3p4+W8gELQVo8N13JkluMfmn2sQ";
                  }
                ];
              }
            ];
            prefer_direct_fetch = false;
          };
        };
        loadCredential = [ "private_key:${config.age.secrets.matrix-global-private-key.path}" ];
      };

      systemd.services.dendrite.serviceConfig = {
        # Allow R/W to media path
        ReadWritePaths = [ cfg.dataPath ];

        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = "dendrite";
        Group = "dendrite";
      };

      # Create user
      users.users.dendrite = {
        group = "dendrite";
        isSystemUser = true;
      };
      users.groups.dendrite = { };

      # PostgreSQL
      codgician.services.postgresql.enable = true;
      services.postgresql = {
        ensureDatabases = [ dbName ];
        ensureUsers = [
          {
            name = "dendrite";
            ensureDBOwnership = true;
          }
        ];
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
      extraVhostConfig =
        let
          # Metadata for matrix server and client
          clientConfig = {
            "m.homeserver".base_url = "https://${cfg.domain}";
            "m.identity_server".base_url = "https://vector.im";
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

            # Matrix protocol
            "~ ^/(_matrix|_synapse)" = {
              inherit (cfg.reverseProxy) lanOnly;
              passthru = {
                inherit (cfg.reverseProxy) proxyPass;
                extraConfig = ''
                  client_max_body_size 0;
                  proxy_read_timeout 120;
                '';
              };
            };

            # Announce server & client metadata
            "= /.well-known/matrix/server" = lib.mkIf (!cfg.reverseProxy.proxyAll) {
              inherit (cfg.reverseProxy) lanOnly;
              passthru = {
                return = ''200 '${builtins.toJSON serverConfig}' '';
                extraConfig = ''
                  add_header Content-Type application/json;
                  add_header Access-Control-Allow-Origin *;
                '';
              };
            };

            "= /.well-known/matrix/client" = lib.mkIf (!cfg.reverseProxy.proxyAll) {
              inherit (cfg.reverseProxy) lanOnly;
              passthru = {
                return = ''200 '${builtins.toJSON clientConfig}' '';
                extraConfig = ''
                  add_header Content-Type application/json;
                  add_header Access-Control-Allow-Origin *;
                '';
              };
            };
          };
        };
    })

    {
      assertions = [
        {
          assertion = !cfg.reverseProxy.elementWeb || !cfg.reverseProxy.proxyAll;
          message = "Element web client can only be hosted if `codgician.services.dendrite.reverseProxy.proxyAll` is disabled.";
        }
      ];
    }
  ];
}
