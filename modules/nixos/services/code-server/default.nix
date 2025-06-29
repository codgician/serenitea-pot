{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "code-server";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "Code server";

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "The user to run code-server as.";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "The group to run code-server as.";
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for code-server to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 4444;
      description = "Port for code-server to listen on.";
    };

    hashedPassword = lib.mkOption {
      type = types.str;
      description = ''
        Create the password with: 
        ```
        echo -n 'thisismypassword' | nix run nixpkgs#libargon2 -- "$(head -c 20 /dev/random | base64)" -e
        ```
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://$\{host}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    # Code server configurations
    (lib.mkIf cfg.enable {
      services.code-server = {
        enable = true;
        inherit (cfg)
          host
          port
          user
          group
          hashedPassword
          ;
        auth = "password";
        proxyDomain = builtins.head cfg.reverseProxy.domains;
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
