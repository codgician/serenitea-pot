{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.gitlab;
  types = lib.types;
in
{
  options.codgician.services.gitlab = {
    enable = lib.mkEnableOption "GitLab server.";

    statePath = lib.mkOption {
      type = types.str;
      example = "/mnt/gitlab";
      description = "Path to store GitLab state data.";
    };

    host = lib.mkOption {
      type = types.str;
      example = "gitlab.example.org";
      description = "Host name of the GitLab server.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "gitlab";
      description = "User under which GitLab runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "gitlab";
      description = "Group under which GitLab runs.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for GitLab.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ cfg.host ];
        defaultText = ''[ config.codgician.services.gitlab.host ]'';
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    # GitLab configurations
    (lib.mkIf cfg.enable {
      services.gitlab = rec {
        enable = true;
        packages.gitlab = pkgs.gitlab;
        inherit (cfg)
          statePath
          host
          user
          group
          ;
        https = true;
        port = 443;

        # Secrets
        initialRootPasswordFile = config.age.secrets.gitlabInitRootPasswd.path;
        secrets = {
          dbFile = config.age.secrets.gitlabDb.path;
          jwsFile = config.age.secrets.gitlabJws.path;
          otpFile = config.age.secrets.gitlabOtp.path;
          secretFile = config.age.secrets.gitlabSecret.path;
        };

        # Mail settings
        smtp = {
          enable = true;
          enableStartTLSAuto = true;
          tls = false;
          authentication = "login";
          address = "smtp.office365.com";
          port = 587;
          username = "bot@codgician.me";
          passwordFile = config.age.secrets.gitlabSmtp.path;
          domain = "codgician.me";
        };
        extraConfig.gitlab = {
          email_from = smtp.username;
          email_reply_to = smtp.username;
        };

        # OmniAuth
        extraConfig.omniauth = {
          enabled = true;
          allow_single_sign_on = [ "github" ];
          block_auto_created_users = true;
          providers = [
            {
              name = "github";
              label = "GitHub";
              app_id = "3bc605d269d8117af816";
              app_secret = {
                _secret = config.age.secrets.gitlabOmniAuthGitHub.path;
              };
              args = {
                scope = "user:email";
              };
            }
          ];
        };
      };

      # PostgreSQL
      codgician.services.postgresql.enable = true;
    })

    # Agenix secrets
    (lib.mkIf cfg.enable (
      with lib.codgician;
      mkAgenixConfigs { owner = cfg.user; } (
        builtins.map getAgeSecretPathFromName [
          "gitlabInitRootPasswd"
          "gitlabDb"
          "gitlabJws"
          "gitlabOtp"
          "gitlabSecret"
          "gitlabSmtp"
          "gitlabOmniAuthGitHub"
        ]
      )
    ))

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.gitlab = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };
    })
  ];
}
