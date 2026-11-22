{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "dsh-web";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;

  # dsh runs as the user's Home Manager service, in the user's session
  # environment, with its providers patch in ~/.dsh and the package that loads
  # the Dendro key.
  hmCfg = config.home-manager.users.${cfg.user};
  domain = builtins.head config.codgician.services.nginx.reverseProxies.${serviceName}.domains;

  # The launch token changes with every process. The printed URL is published
  # as a redirect page that nginx hands to browsers dsh does not recognize.
  runtimeDir = "/run/${serviceName}";
  launchPage = "${runtimeDir}/launch.html";
  launchLocation = "/.dsh-launch";

  # The service has no XDG Documents directory to discover.
  webPatch = (pkgs.formats.yaml { }).generate "dsh-web.patch.yml" [
    {
      id = "workspace-controller";
      config.documentsDirectory = "${hmCfg.home.homeDirectory}/Documents";
    }
  ];

  start = pkgs.writeShellScript "dsh-web-start" ''
    umask 027
    page=${lib.escapeShellArg launchPage}
    exec > >(
      while IFS= read -r line; do
        printf '%s\n' "$line"
        case $line in
          "dsh web: https://"*)
            printf '<!doctype html><meta name="referrer" content="no-referrer"><meta http-equiv="refresh" content="0;url=%s">\n' \
              "''${line#"dsh web: "}" >"$page.tmp" && mv -f "$page.tmp" "$page"
            ;;
        esac
      done
    )
    exec ${
      lib.escapeShellArgs [
        (lib.getExe hmCfg.codgician.codgi.dsh.wrappedPackage)
        "web"
        "--patch"
        (toString webPatch)
        "--host"
        "127.0.0.1"
        "--port"
        (toString cfg.port)
        "--no-open"
        "--public-url"
        "https://${domain}/"
        "--trusted-host"
        domain
      ]
    }
  '';

  proxyConfig = ''
    # dsh's launch URL carries a process credential.
    access_log off;
    proxy_cookie_flags ~^dsh-auth- secure;
    proxy_buffering off;
  '';
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "the dsh (DeepSeek Harness) Web UI";

    user = lib.mkOption {
      type = types.str;
      example = "codgi";
      description = "User whose Home Manager session runs the Web UI.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 3080;
      description = "Loopback port for the dsh Web UI.";
    };
  };

  config = lib.mkMerge [
    {
      codgician.services.nginx.reverseProxies.${serviceName} = {
        domains = [ "moongazer.${lib.codgician.zone}" ];
        # Whoever passes gets a shell as the service user.
        authelia.users = [ "codgician" ];
      };
    }

    (lib.mkIf cfg.enable {
      home-manager.users.${cfg.user} = {
        codgician.codgi.dsh.enable = true;

        systemd.user.services.${serviceName} = {
          Unit.Description = "DeepSeek Harness Web UI";
          Service = {
            ExecStart = toString start;
            ExecStopPost = "${lib.getExe' pkgs.coreutils "rm"} -f ${launchPage}";
            WorkingDirectory = "%h";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      codgician.services.nginx.reverseProxies.${serviceName} = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        locations = {
          "/".extraConfig = proxyConfig;

          # Only the index exchanges the launch token. When dsh refuses it,
          # hand the browser the current launch URL.
          "= /" = {
            extraConfig = proxyConfig;
            authelia.onUpstreamUnauthorized = ''
              # A launch URL that still fails is from the previous process.
              if ($arg_token) {
                return 503;
              }
              rewrite ^ ${launchLocation} last;
            '';
          };

          "= ${launchLocation}" = {
            alias = launchPage;
            extraConfig = ''
              internal;
              access_log off;
              default_type text/html;
              add_header Cache-Control "no-store" always;
            '';
          };
        };
      };

      # A user service cannot hand files to nginx's group; setgid on this
      # directory does.
      systemd.tmpfiles.rules = [
        "d ${runtimeDir} 2750 ${cfg.user} ${config.services.nginx.group} -"
      ];
    })
  ];
}
