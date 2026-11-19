{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.services.jupyter;
  svc = config.codgician.inventory.services.jupyter;
in
{
  imports = [ ./kernels ];

  options.codgician.services.jupyter = {
    enable = lib.codgician.mkPublishedEnableOption config "jupyter";

    notebookDir = lib.mkOption {
      type = lib.types.str;
      default = "~/";
      description = "Root directory for notebooks.";
    };
  };

  config = lib.mkIf cfg.enable {
    codgician.services.nginx.reverseProxies.jupyter.proxyPass = svc.localUpstream;

    services.jupyter = {
      enable = true;
      ip = "127.0.0.1";
      inherit (svc) port;
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

    assertions = [
      {
        assertion = svc.authelia != null;
        message = "jupyter runs without authentication of its own: put it behind Authelia in the inventory.";
      }
    ];
  };
}
