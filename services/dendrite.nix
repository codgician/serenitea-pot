# Referenced https://github.com/Mic92/dotfiles/blob/main/nixos/eve/modules/dendrite.nix
# Huge thanks to @Mic92

{ config, pkgs, ... }:
let
  domain = "matrix.codgician.me";
  dbName = "dendrite";
  database = {
    connection_string = "postgres:///${dbName}?host=/run/postgresql";
    max_open_conns = 80;
    max_idle_conns = 5;
    conn_max_lifetime = -1;
  };

  # Server & client metadata
  server = {
    "m.server" = "${domain}:443";
  };
  client = {
    "m.homeserver" = { 
      "base_url" = "https://${domain}";
      "server_name" = "${domain}";
    };
    "org.matrix.msc3575.proxy"."url" = "https://${domain}";
    "m.identity_server"."base_url" = "https://vector.im";
  };

  # Web client
  element-web-codgician-me =
    pkgs.runCommand "element-web-codgician-me"
      {
        nativeBuildInputs = [ pkgs.buildPackages.jq ];
      } ''
      cp -r ${pkgs.element-web} $out
      chmod -R u+w $out
      jq '."default_server_config" = ${builtins.toJSON client}' \
        > $out/config.json < ${pkgs.element-web}/config.json
      ln -s $out/config.json $out/config.${domain}.json
    '';
in
{
  # Dendrite
  services.dendrite = {
    enable = true;
    openRegistration = false;
    environmentFile = config.age.secrets.matrixEnv.path;
    settings = {
      global = {
        server_name = domain;
        private_key = "$CREDENTIALS_DIRECTORY/private_key";
        trusted_third_party_id_servers = [
          "matrix.org"
          "libera.chat"
          "nixos.org"
          "gitter.im"
          "vector.im"
        ];
        metrics.enabled = true;
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
        base_path = "/mnt/data/dendrite/media_store";
        dynamic_thumbnails = true;
      };

      key_server = {
        inherit database;
      };

      mscs = {
        inherit database;
        mscs = [
          # Support Threads
          # see: https://github.com/matrix-org/dendrite/blob/main/docs/FAQ.md#does-dendrite-support-threads
          "msc2836"

          # Sliding sync
          # see: https://github.com/matrix-org/sliding-sync
          "msc3575"
        ];
      };

      client_api = {
        registration_disabled = false;
        recaptcha_public_key = "6LfaZzopAAAAABF3bgWvpyacT6RKllDzRJgkJqaA";
        recaptcha_private_key = "$RECAPTCHA_PRIVATE_KEY";
        enable_registration_captcha = true;
        recaptcha_siteverify_api = "https://www.google.com/recaptcha/api/siteverify";
        recaptcha_api_js_url = "https://www.recaptcha.net/recaptcha/api.js";

        turn_uris = [ 
          "turn:turn.codgician.me?transport=udp"
          "turn:turn.codgician.me?transport=tcp"
        ];
        turn_shared_secret = "$TURN_SHARED_SECRET";
      };

      relay_api = {
        inherit database;
      };

      room_server = {
        inherit database;
      };

      push_server = {
        inherit database;
      };

      sync_api = {
        inherit database;
        real_ip_header = "X-Real-IP";
      };

      user_api = {
        account_database = database;
        device_database = database;
      };

      federation_api = {
        inherit database;
      };
    };

    loadCredential = [
      "private_key:${config.age.secrets.matrixGlobalPrivateKey.path}"
    ];
  };

  # Matrix sliding-sync
  services.matrix-synapse.sliding-sync = {
    enable = true;
    settings.SYNCV3_SERVER = "https://${domain}";
    environmentFile = config.age.secrets.matrixEnv.path;
  };

  # Configure PostgresSQL
  services.postgresql = {
    ensureDatabases = [ dbName ];
    ensureUsers = [
      {
        name = dbName;
        ensureDBOwnership = true;
      }
    ];
  };

  # Protect secrets
  age.secrets =
    let
      secretsDir = builtins.toString ../secrets;
      nameToObj = name: {
        "${name}" = {
          file = "${secretsDir}/${name}.age";
          owner = "root";
          mode = "600";
        };
      };
    in
    builtins.foldl' (x: y: x // y) { } (map (nameToObj) [ "matrixGlobalPrivateKey" "matrixEnv" ]);  

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/".root = element-web-codgician-me;
    locations."/_matrix/" = {
      proxyPass = "http://[::1]:${builtins.toString config.services.dendrite.httpPort}";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        proxy_buffering off;
      '';
    };

    locations."= /.well-known/matrix/server".extraConfig = ''
      add_header Content-Type application/json;
      return 200 '${builtins.toJSON server}';
    '';

    locations."= /.well-known/matrix/client".extraConfig = ''
      add_header Content-Type application/json;
      add_header Access-Control-Allow-Origin *;
      return 200 '${builtins.toJSON client}';
    '';

    locations."/_synapse".proxyPass = "http://[::1]:${toString config.services.dendrite.httpPort}";
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };
}
