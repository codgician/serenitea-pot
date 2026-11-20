{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.postfix;
  types = lib.types;
  tokenFile = "/var/lib/postfix/tokens/${cfg.sender}";
  saslPasswd = pkgs.writeText "sasl_passwd" ''
    [smtp.office365.com]:587 ${cfg.sender}:${tokenFile}
  '';
in
{
  options.codgician.services.postfix = {
    enable = lib.mkEnableOption "postfix";

    verbose = lib.mkEnableOption "debugging logs";

    saslPackage = lib.mkPackageOption pkgs [ "nur" "repos" "codgician" "sasl-xoauth2" ] {
      extraDescription = "It is the SASL mechanism postfix signs in to the relay with.";
    };

    sender = lib.mkOption {
      type = types.str;
      default = "bot@${lib.codgician.zone}";
      readOnly = true;
      description = "Mailbox the relay signs in as; every service sends its mail from it.";
    };

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
      cfg.saslPackage
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
          sender_canonical_maps = "static:${cfg.sender}";

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

        master = lib.mkIf cfg.verbose {
          relay.args = [ "-v" ];
          smtp.args = [ "-v" ];
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
      cfg.saslPackage
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
