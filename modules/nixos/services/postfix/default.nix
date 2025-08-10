{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "postfix";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
  tokenFile = "/var/lib/postfix/tokens/bot@codgician.me";
  saslPasswd = pkgs.writeText "sasl_passwd" ''
    [smtp.office365.com]:587 bot@codgician.me:${tokenFile}
  '';

  # TODO: remove this as fixed upstream
  sasl-xoauth2 = pkgs.nur.repos.codgician.sasl-xoauth2.overrideAttrs (_: {
    postPatch = ''
      substituteInPlace src/CMakeLists.txt scripts/sasl-xoauth2-tool.in \
        --replace-fail "\''${CMAKE_INSTALL_FULL_SYSCONFDIR}" '/etc'
    '';
  });
in
{
  options.codgician.services.postfix = {
    enable = lib.mkEnableOption "postfix";

    verbose = lib.mkEnableOption "debugging logs";

    user = lib.mkOption {
      type = types.str;
      default = "postfix";
      description = "User under which postfix runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "postfix";
      description = "Group under which postfix runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Make debugging easier
    environment.systemPackages = with pkgs; [
      sasl-xoauth2
      cyrus_sasl
    ];

    # Configure postfix
    services.postfix = {
      enable = true;
      inherit (cfg) user group;
      relayHost = "smtp.office365.com";
      relayPort = 587;
      config = {
        import_environment = "SASL_PATH";
        mynetworks = "127.0.0.0/8";
        inet_interfaces = "loopback-only";
        inet_protocols = "all";
        sender_canonical_maps = "static:bot@codgician.me";

        # SMTP
        smtp_tls_security_level = "encrypt";
        smtp_always_send_ehlo = "yes";

        # XOAuth2
        smtp_sasl_auth_enable = "yes";
        smtp_sasl_password_maps = "texthash:${saslPasswd.outPath}";
        smtp_sasl_security_options = "";
        smtp_sasl_mechanism_filter = "xoauth2";
      };

      masterConfig = lib.mkIf cfg.verbose {
        "relay".args = [ "-v" ];
        "smtp".args = [ "-v" ];
      };
    };

    codgician.system = {
      # Agenix secret for OAuth2 token
      agenix.secrets."sasl-xoauth2" = {
        owner = cfg.user;
        group = cfg.group;
        mode = "0600";
      };

      # Impermanence
      impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/postfix";
          user = cfg.user;
          group = cfg.group;
          mode = "0600";
        }
      ];
    };

    systemd.services.postfix.environment.SASL_PATH = lib.makeSearchPath "lib/sasl2" [
      sasl-xoauth2
    ];

    environment.etc."sasl-xoauth2.conf" = {
      inherit (cfg) group user;
      mode = "0600";
      source = config.age.secrets.sasl-xoauth2.path;
    };

    # Add an activation script to check token file existence
    # If not, print a warning asking user to manually create it
    system.activationScripts.checkPostfixPasswordFiles = {
      deps = [ "users" ];
      text = ''
        if [ ! -f "${tokenFile}" ]; then
          echo -e "\033[0;33m[postfix] WARNING: Token file not found at ${tokenFile}, use sasl-xoauth2-tool to create it.\033[0m"
        else
          chown ${cfg.user}:${cfg.group} '${tokenFile}'
          chmod 0600 '${tokenFile}'
        fi
      '';
    };
  };
}
