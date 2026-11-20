{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.services.jupyter;
  port = 8888;
in
{
  imports = [ ./kernels ];

  options.codgician.services.jupyter = {
    enable = lib.mkEnableOption "Jupyter";

    notebookDir = lib.mkOption {
      type = lib.types.str;
      default = "~/";
      description = "Root directory for notebooks.";
    };
  };

  config = lib.mkMerge [
    {
      codgician.services.nginx.reverseProxies.jupyter = {
        domains = [ "dragonspine.${lib.codgician.zone}" ];
        # Jupyter runs without authentication of its own.
        authelia.anyone = true;
      };
    }

    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.jupyter.proxyPass = "http://127.0.0.1:${toString port}";

      services.jupyter = {
        enable = true;
        ip = "127.0.0.1";
        inherit port;
        inherit (cfg) notebookDir;
        user = "codgi";
        group = "jupyter";

        # Authelia handles authentication: no password, and no token either
        password = "";
        notebookConfig = ''
          c.ServerApp.allow_remote_access = True
          c.ServerApp.trust_xheaders = True
          # Disable built-in authentication - Authelia handles auth
          c.ServerApp.token = ""
          c.PasswordIdentityProvider.hashed_password = ""
        '';
      };
    })
  ];
}
