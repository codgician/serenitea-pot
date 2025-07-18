{
  options,
  lib,
  pkgs,
  ...
}:
let
  types = lib.types;
  autheliaInstances = builtins.attrNames options.codgician.services.authelia.instances;
in
{
  options = {
    enable = lib.mkEnableOption "Nginx reverse proxy profile for this service.";

    authelia = lib.mkOption {
      type = with types; nullOr (enum autheliaInstances);
      default = null;
      description = ''
        Authelia instance to use for authentication.
        If set, the reverse proxy will be configured to use Authelia for authentication.
      '';
    };

    https = lib.mkEnableOption "Use https and auto-renew certificates.";

    domains = lib.mkOption {
      type = types.listOf types.str;
      example = [
        "example.com"
        "example.org"
      ];
      default = [ ];
      description = "List of domains for the reverse proxy.";
    };

    locations = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./location-options.nix { inherit lib pkgs; }));
      default = { };
      example = lib.literalExpression ''
        {
          "/".proxyPass = "http://127.0.0.1:8000";
        }
      '';
      description = "Declare nginx locations config.";
    };

    robots = lib.mkOption {
      type = types.str;
      example = ''
        User-agent: *
        Disallow: *
      '';
      default = "";
      description = ''
        Content of `/robots.txt`.
      '';
    };
  };
}
