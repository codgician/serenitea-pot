{
  config,
  pkgs,
  lib,
  ...
}:
let
  serviceName = "jupyter";
  cfg = config.codgician.services.jupyter;
  types = lib.types;
  svc = lib.codgician.published.services.jupyter;
in
{
  imports = [ ./kernels ];

  options.codgician.services.jupyter = {
    enable = lib.codgician.mkPublishedEnableOption config serviceName;

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "User under which Jupyter runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which Jupyter runs.";
    };

    notebookDir = lib.mkOption {
      type = types.str;
      default = "~/";
      description = "Root directory for notebooks.";
    };

    password = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "argon2:$argon2id$v=19$m=10240,t=10,p=8$...";
      description = ''
        Hashed password for Jupyter authentication.
        When null and the inventory puts Jupyter behind Authelia, Jupyter auth is disabled.
        When null and authelia is not enabled, an assertion will fail.

        Generate with: `jupyter server password` or
        `python3 -c "from jupyter_server.auth import passwd; print(passwd('your-password'))"`
      '';
    };

    extraTools = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression ''
        [ pkgs.git pkgs.graphviz pkgs.pandoc ]
      '';
      description = ''
        Extra command-line tools available in Jupyter terminal sessions
        and notebook shell commands (!, %%, system calls).

        These are added to the Jupyter systemd service PATH,
        making them available ONLY in Jupyter context, not system-wide.
      '';
    };
  };

  config =
    let
      # Disable Jupyter auth when Authelia handles it
      disableJupyterAuth = cfg.password == null && svc.authelia != null;
    in
    lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.jupyter.proxyPass = svc.localUpstream;

      services.jupyter = {
        enable = true;
        ip = "127.0.0.1";
        inherit (svc) port;
        inherit (cfg)
          user
          group
          notebookDir
          ;

        # Use provided password hash, or empty string (which triggers token mode normally,
        # but we disable token via notebookConfig when using Authelia)
        password = if cfg.password != null then cfg.password else "";

        notebookConfig =
          # Base config for reverse proxy
          ''
            c.ServerApp.allow_remote_access = True
            c.ServerApp.trust_xheaders = True
          ''
          # Disable token/password auth when Authelia handles it
          + (lib.optionalString disableJupyterAuth ''
            # Disable built-in authentication - Authelia handles auth
            c.ServerApp.token = ""
            c.PasswordIdentityProvider.hashed_password = ""
          '');
      };

      # Add extra tools to Jupyter service PATH
      systemd.services.jupyter.path = lib.mkIf (cfg.extraTools != [ ]) (lib.mkAfter cfg.extraTools);

      # Ensure authentication is configured
      assertions = [
        {
          assertion = cfg.password != null || svc.authelia != null;
          message = ''
            jupyter: Authentication is required.

            Either:
            1. Put it behind Authelia in the inventory (recommended)
            2. Provide a password hash: password = "argon2:..."
          '';
        }
      ];
    };
}
