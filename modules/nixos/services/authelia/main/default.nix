{ config, lib, ... }:
let
  name = "main";
  serviceName = "authelia-${name}";
  cfg = config.codgician.services.authelia.${name};
  types = lib.types;
in
{
  options.codgician.services.authelia.${name} = {
    enable = lib.mkEnableOption "Authelia instance ${name}";

    address = lib.mkOption {
      type = types.str;
      default = "unix:///run/authelia/main.sock";
      description = ''
        Address for Authelia instance ${name} to listen on.
        Use a Unix socket for local communication.
      '';
    };

    domain = lib.mkOption {
      type = types.str;
      example = "example.com";
      description = "The session domain for Authelia instance ${name}.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "authelia-${name}";
      description = "User under which Authelia instance ${name} runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "authelia-${name}";
      description = "Group under which Authelia instance ${name} runs.";
    };

    database = lib.mkOption {
      type = types.enum [
        "sqlite"
        "postgresql"
      ];
      default = "sqlite";
      example = "postgresql";
      description = "Database backend for Authelia instance ${name}.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://unix:/run/${serviceName}/main.sock";
      defaultDomains = [ "auth.${cfg.domain}" ];
      defaultDomainsText = ''with config.codgician.services.authelia.${name}; [ "auth.$\{domain}" ]'';
    };
  };

  config = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      {
        services.authelia.instances.${name} = {
          enable = true;
          inherit (cfg) user group;

          environmentVariables = {
            AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.age.secrets."authelia-main-smtp".path;
          };

          secrets = {
            jwtSecretFile = config.age.secrets."authelia-main-jwt".path;
            sessionSecretFile = config.age.secrets."authelia-main-session".path;
            storageEncryptionKeyFile = config.age.secrets."authelia-main-storage".path;
          };

          settings = {
            theme = "auto";
            server.address = "unix:///run/${serviceName}/main.sock?umask=000";
            log.level = "debug";
            default_2fa_method = "webauthn";

            # Use file backend for simplicity
            authentication_backend.file = {
              path = "/var/lib/authelia-main/users.yml";
              search.email = true;
              password = {
                algorithm = "argon2";
                argon2 = {
                  variant = "argon2id";
                  iterations = 3;
                  memory = 65536;
                  parallelism = 4;
                  key_length = 32;
                  salt_length = 16;
                };
              };
            };

            session = {
              name = "authelia_session_${name}";
              cookies = [
                {
                  inherit (cfg) domain;
                  authelia_url = "https://auth.${cfg.domain}";
                }
              ];
              redis = {
                host = config.services.redis.servers.${serviceName}.unixSocket;
              };
            };

            storage = {
              postgres = lib.mkIf (cfg.database == "postgresql") {
                address = "unix:///run/postgresql";
                database = "authelia-${name}";
                username = "authelia-${name}";
              };
            };

            access_control = {
              # todo: define rules
              default_policy = "two_factor";
            };

            notifier = {
              smtp = {
                address = "smtp://smtp.office365.com:587";
                username = "bot@codgician.me";
                # password provided by AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE
                sender = "bot@codgician.me";
                subject = "[Authelia] {title}";
                identifier = cfg.domain;
                timeout = "15s";
                startup_check_address = "test@authelia.com";
                tls = {
                  server_name = "smtp.office365.com";
                  minimum_version = "TLS1.2";
                };
              };
            };

            webauthn = {
              enable_passkey_login = true;
              metadata = {
                enabled = true;
                validate_trust_anchor = true;
                validate_entry = true;
                validate_status = true;
                validate_entry_permit_zero_aaguid = false;
              };
            };
          };
        };

        # Grant access to /run
        systemd.services.${serviceName}.serviceConfig = {
          RuntimeDirectory = serviceName;
          RuntimeDirectoryMode = "0755";
        };

        # Redis
        services.redis.servers.${serviceName} = {
          enable = true;
          inherit (cfg) user group;
          unixSocketPerm = 660;
        };

        # Agenix secrets
        codgician.system.agenix.secrets =
          lib.genAttrs
            [
              "authelia-main-jwt"
              "authelia-main-session"
              "authelia-main-storage"
              "authelia-main-smtp"
            ]
            (name: {
              owner = cfg.user;
              group = cfg.group;
              mode = "0600";
            });

        # Persist default data directory
        codgician.system.impermanence.extraItems = [
          {
            type = "directory";
            path = "/var/lib/${serviceName}";
            inherit (cfg) user group;
          }
        ];
      }

      # PostgreSQL
      (lib.mkIf (cfg.database == "postgresql") {
        codgician.services.postgresql.enable = true;
        services.postgresql = {
          ensureDatabases = [ "authelia-${name}" ];
          ensureUsers = [
            {
              name = "authelia-${name}";
              ensureDBOwnership = true;
            }
          ];
        };
      })

      # Reverse proxy profile
      (lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      })
    ]
  );
}
