{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.postfix;
  types = lib.types;
  inherit (lib.codgician.inventory) mail;
  tokenFile = "/var/lib/postfix/tokens/${mail}";
  saslPasswd = pkgs.writeText "sasl_passwd" ''
    [smtp.office365.com]:587 ${mail}:${tokenFile}
  '';
in
{
  options.codgician.services.postfix = {
    enable = lib.mkEnableOption "postfix";

    authorizedUsers = lib.mkOption {
      type = with types; listOf str;
      default = [
        "root"
        "postfix"
      ];
      example = [
        "user1"
        "user2"
      ];
      description = "List of users authorized to interact with postfix.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Make debugging easier
    environment.systemPackages = with pkgs; [
      pkgs.nur.repos.codgician.sasl-xoauth2
      cyrus_sasl
    ];

    # Configure postfix
    services.postfix = {
      enable = true;

      settings = {
        main = rec {
          relayhost = [ "[smtp.office365.com]:587" ];
          mynetworks = [
            "127.0.0.0/8"
            "[::ffff:127.0.0.0]/104"
            "[::1]/128"
          ];

          import_environment = "SASL_PATH";
          inet_interfaces = "loopback-only";
          inet_protocols = "all";
          sender_canonical_maps = "static:${mail}";

          # Access control
          authorized_submit_users = builtins.concatStringsSep ", " (lib.unique cfg.authorizedUsers);
          authorized_mailq_users = authorized_submit_users;
          authorized_flush_users = authorized_submit_users;

          # SMTP
          smtp_tls_security_level = "encrypt";
          smtp_always_send_ehlo = "yes";

          # XOAuth2
          smtp_sasl_auth_enable = "yes";
          smtp_sasl_password_maps = "texthash:${saslPasswd.outPath}";
          smtp_sasl_security_options = "";
          smtp_sasl_mechanism_filter = "xoauth2";
        };
      };
    };

    codgician.secrets.files."sasl-xoauth2" = {
      owner = "postfix";
      group = "postfix";
      mode = "0600";
    };

    codgician.system = {
      # Impermanence
      impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/postfix";
          user = "postfix";
          group = "postfix";
          mode = "0600";
        }
      ];
    };

    systemd.services.postfix.environment.SASL_PATH = lib.makeSearchPath "lib/sasl2" [
      pkgs.nur.repos.codgician.sasl-xoauth2
    ];

    environment.etc."sasl-xoauth2.conf" = {
      mode = "direct-symlink";
      source = config.codgician.secrets.files.sasl-xoauth2.path;
    };

    # Add an activation script to check token file existence
    # If not, print a warning asking user to manually create it
    system.activationScripts.checkPostfixPasswordFiles = {
      deps = [ "users" ];
      text = ''
        if [ ! -f "${tokenFile}" ]; then
          echo -e "\033[0;33m[postfix] WARNING: Token file not found at ${tokenFile}, use sasl-xoauth2-tool to create it.\033[0m"
        else
          chown postfix:postfix '${tokenFile}'
          chmod 0600 '${tokenFile}'
        fi
      '';
    };
  };
}
