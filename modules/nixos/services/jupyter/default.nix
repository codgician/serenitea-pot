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
in
{
  imports = [ ./kernels ];

  options.codgician.services.jupyter = {
    enable = lib.mkEnableOption "Jupyter";

    ip = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for Jupyter to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8888;
      description = "Port for Jupyter to listen on.";
    };

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
        When null and reverseProxy.authelia.enable = true, Jupyter auth is disabled.
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

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.ip}:${builtins.toString cfg.port}";
      defaultProxyPassText = "with config.codgician.services.jupyter; http://\${ip}:\${builtins.toString port}";
    };
  };

  config =
    let
      # Disable Jupyter auth when Authelia handles it
      disableJupyterAuth = cfg.password == null && cfg.reverseProxy.authelia.enable;
    in
    lib.mkMerge [
      # Jupyter configurations
      (lib.mkIf cfg.enable {
        services.jupyter = {
          enable = true;
          inherit (cfg)
            ip
            port
            user
            group
            notebookDir
            ;

          # Use provided password hash, or empty string (which triggers token mode normally,
          # but we disable token via notebookConfig when using Authelia)
          password = if cfg.password != null then cfg.password else "";

          notebookConfig =
            # Base config for reverse proxy
            (lib.optionalString cfg.reverseProxy.enable ''
              c.ServerApp.allow_remote_access = True
              c.ServerApp.trust_xheaders = True
            '')
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
            assertion = cfg.password != null || cfg.reverseProxy.authelia.enable;
            message = ''
              jupyter: Authentication is required.

              Either:
              1. Enable Authelia: reverseProxy.authelia.enable = true (recommended)
              2. Provide a password hash: password = "argon2:..."
            '';
          }
        ];
      })

      # Reverse proxy profile
      (lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      })
    ];
}
