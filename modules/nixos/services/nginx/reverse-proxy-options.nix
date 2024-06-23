{ lib, ... }:
let
  types = lib.types;
in
{
  options = {
    enable = lib.mkEnableOption ''
      Enable nginx reverse proxy profile for this service.
    '';

    default = lib.mkEnableOption ''
      Make this profile the default virtual host.
    '';

    https = lib.mkEnableOption ''
      Use https and auto-renew certificates.
    '';

    domains = lib.mkOption {
      type = types.listOf types.str;
      example = [ "example.com" "example.org" ];
      default = [ ];
      description = lib.mdDoc ''
        List of domains for the reverse proxy.
      '';
    };

    locations = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./location-options.nix { inherit lib; }));
      default = { };
      example = lib.literalExpression ''
        {
          "/".proxyPass = "http://127.0.0.1:8000";
        }
      '';
    };

    robots = lib.mkOption {
      type = types.str;
      example = ''
        User-agent: *
        Disallow: *
      '';
      default = "";
      description = lib.mdDoc ''
        Content of `/robots.txt`.
      '';
    };
  };
}
