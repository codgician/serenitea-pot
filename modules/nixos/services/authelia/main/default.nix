args@{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "main";
  serviceName = "authelia-${name}";
  user = serviceName;
  group = serviceName;
  cfg = config.codgician.services.authelia.instances.${name};
  inherit (lib.codgician) inventory published;
  svc = published.services.${serviceName};
in
{
  options.codgician.services.authelia.instances.${name}.enable =
    lib.codgician.mkPublishedEnableOption config serviceName;

  config = lib.mkIf cfg.enable {
    codgician.services.nginx.reverseProxies.${serviceName}.proxyPass =
      "http://unix:/run/${serviceName}/${name}.sock";

    services.authelia.instances.${name} = {
      enable = true;
      inherit user group;

      secrets = {
        jwtSecretFile = config.codgician.secrets.files."authelia-main-jwt".path;
        sessionSecretFile = config.codgician.secrets.files."authelia-main-session".path;
        storageEncryptionKeyFile = config.codgician.secrets.files."authelia-main-storage".path;
      };

      settingsFiles = [
        config.codgician.secrets.files."authelia-main-jwks".path
      ];

      settings = {
        theme = "auto";
        server.address = "unix:///run/${serviceName}/${name}.sock?umask=0117";
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
              domain = inventory.zone;
              authelia_url = "https://${svc.domain}";
            }
          ];
          redis = {
            host = config.services.redis.servers.${serviceName}.unixSocket;
          };
        };

        storage = {
          postgres = {
            address = "unix:///run/postgresql";
            database = "authelia-${name}";
            username = "authelia-${name}";
          };
        };

        access_control = {
          default_policy = "two_factor";
          rules = published.autheliaRules ++ [
            # Explicit catch-all matching default_policy: functionally
            # identical to relying on default_policy, but silences
            # Authelia's "no rules specified" startup warning.
            {
              domain_regex = "^.*$";
              policy = "two_factor";
            }
          ];
        };

        notifier = {
          smtp = {
            address = "smtp://localhost:25";
            sender = "bot@codgician.me";
            subject = "[Authelia] {title}";
            identifier = inventory.zone;
            timeout = "15s";
            startup_check_address = "bot@codgician.me";
            # Local smtp relay (postfix on localhost:25) doesn't offer
            # STARTTLS; disable_require_tls alone (opportunistic TLS) is
            # sufficient and avoids the disable_starttls insecure-plaintext
            # warning.
            disable_require_tls = true;
          };
        };

        totp = {
          issuer = inventory.zone;
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
            attachment = "";
            discoverability = "required";
            user_verification = "required";
          };
          metadata = {
            enabled = false;
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

      # Exponential restart backoff: avoids hammering upstream dependencies
      # (e.g. the WebAuthn MDS3 metadata service) with a request every
      # RestartSec while crash-looping.
      RestartSteps = 5;
      RestartMaxDelaySec = "5min";
    };

    # Add nginx to authelia group for socket access
    users.groups.${group}.members = lib.mkIf config.services.nginx.enable [ "nginx" ];

    # Redis
    services.redis.servers.${serviceName} = {
      enable = true;
      inherit user group;
      unixSocketPerm = 660;
    };

    # sops secrets
    codgician.secrets.files =
      lib.genAttrs
        [
          "authelia-main-jwt"
          "authelia-main-session"
          "authelia-main-storage"
          "authelia-main-jwks"
        ]
        (name: {
          owner = user;
          inherit group;
          mode = "0600";
        });

    # Persist default data directory
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/${serviceName}";
        inherit user group;
      }
    ];

    # PostgreSQL
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
  };
}
