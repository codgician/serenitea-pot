{
  lib,
  serviceName ? null,
  defaultDomains ? [ ],
  defaultDomainsText ? null,
}:
let
  types = lib.types;
  serviceName' = if serviceName == null then "this service" else serviceName;
in
{
  options = {
    enable = lib.mkEnableOption "Nginx reverse proxy profile for ${serviceName'}.";

    authelia = {
      enable = lib.mkEnableOption "Authelia";

      url = lib.mkOption {
        type = types.str;
        default = "https://auth.codgician.me";
        example = "https://auth.example.com";
        description = "The URL of the Authelia.";
      };
    };

    https = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Use https and auto-renew certificates.";
    };

    domains = lib.mkOption {
      type = types.listOf types.str;
      example = [
        "example.com"
        "example.org"
      ];
      default = defaultDomains;
      defaultText = lib.mkIf (defaultDomainsText != null) defaultDomainsText;
      description = "List of domains for the reverse proxy.";
    };

    locations = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./location-options.nix { inherit lib; }));
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
