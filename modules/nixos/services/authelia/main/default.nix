args@{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "main";
  serviceName = "authelia-${name}";
  cfg = config.codgician.services.authelia.instances.${name};
  types = lib.types;
in
{
  options.codgician.services.authelia.instances.${name} = {
    enable = lib.mkEnableOption "Authelia instance ${name}";

    sessionDomain = lib.mkOption {
      type = types.str;
      example = "example.com";
      description = "The session domain for Authelia instance ${name}.";
    };

    domain = lib.mkOption {
      type = types.str;
      default = "auth.${cfg.sessionDomain}";
      defaultText = "$\{config.codgician.services.authelia.$\{name\}.domain\}";
      example = "auth.example.com";
      description = "The authentication domain for Authelia instance ${name}.";
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
      defaultProxyPass = "http://unix:/run/${serviceName}/${name}.sock";
      defaultDomains = [ "${cfg.domain}" ];
      defaultDomainsText = ''with config.codgician.services.authelia.${name}; [ domain ]'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.authelia.instances.${name} = {
        enable = true;
        inherit (cfg) user group;

        secrets = {
          jwtSecretFile = config.age.secrets."authelia-main-jwt".path;
          sessionSecretFile = config.age.secrets."authelia-main-session".path;
          storageEncryptionKeyFile = config.age.secrets."authelia-main-storage".path;
        };

        settingsFiles = [
          config.age.secrets."authelia-main-jwks".path
        ];

        settings = {
          theme = "auto";
          server.address = "unix:///run/${serviceName}/${name}.sock?umask=0000";
          default_2fa_method = "webauthn";

          # Identity providers
          identity_providers.oidc = import ./oidc.nix args;

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
            same_site = "lax";
            expiration = "1h";
            inactivity = "5m";
            remember_me = "1M";
            cookies = [
              {
                domain = cfg.sessionDomain;
                authelia_url = "https://${cfg.domain}";
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
            default_policy = "two_factor";
            rules =
              let
                # Function to generate rules for a single reverse proxy config
                mkProxyRules =
                  name: proxyCfg:
                  if !proxyCfg.authelia.enable then
                    [ ]
                  else
                    let
                      domains = proxyCfg.domains;
                      # Map accessRules to Authelia rule format
                      customRules = map (rule: {
                        domain = domains;
                        policy = rule.policy;
                        subject = (map (u: "user:${u}") rule.users) ++ (map (g: "group:${g}") rule.groups);
                      }) proxyCfg.authelia.rules;

                      # Default policy rule for this domain (catch-all for this domain)
                      defaultRule = [
                        {
                          domain = domains;
                          policy = proxyCfg.authelia.defaultPolicy;
                        }
                      ];
                    in
                    customRules ++ defaultRule;

                # Collect all rules from all proxies
                nginxRules = lib.concatLists (
                  lib.mapAttrsToList mkProxyRules config.codgician.services.nginx.reverseProxies
                );
              in
              nginxRules
              ++ [
                # Manual rules can be added here if needed
              ];
          };

          notifier = {
            smtp = {
              address = "smtp://localhost:25";
              sender = "bot@codgician.me";
              subject = "[Authelia] {title}";
              identifier = cfg.sessionDomain;
              timeout = "15s";
              startup_check_address = "bot@codgician.me";

              # Disable TLS for local smtp relay
              disable_require_tls = true;
              disable_starttls = true;
            };
          };

          totp = {
            issuer = "codgician.me";
            algorithm = "SHA1";
            digits = 6;
            period = 30;
            skew = 1;
            secret_size = 32;
            allowed_algorithms = [
              "SHA1"
              "SHA256"
              "SHA512"
            ];
            allowed_digits = [
              6
              8
            ];
            allowed_periods = [ 30 ];
            disable_reuse_security_policy = false;
          };

          webauthn = {
            enable_passkey_login = true;
            attestation_conveyance_preference = "direct";
            experimental_enable_passkey_uv_two_factors = true;
            experimental_enable_passkey_upgrade = true;
            display_name = "Authelia";
            timeout = "60s";
            selection_criteria = {
              attachment = "platform";
              discoverability = "required";
              user_verification = "required";
            };
            metadata = {
              enabled = true;
              validate_entry = false;
            };
          };
        };
      };

      # Add to authorized users of postfix
      codgician.services.postfix.authorizedUsers = [ "root" ];

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
            "authelia-main-jwks"
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
    })

    # PostgreSQL
    (lib.mkIf (cfg.enable && cfg.database == "postgresql") {
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
  ];
}
