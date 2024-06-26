{ lib, ... }:
let
  types = lib.types;
in
{
  options = {
    proxyPass = lib.mkOption {
      type = types.nullOr types.str;
      example = "http://127.0.0.1:8080";
      default = null;
      description = ''
        Target URI of reverse proxy for requests to this location.
      '';
    };

    return = lib.mkOption {
      type = types.nullOr types.str;
      example = "301 http://example.com$request_uri";
      default = null;
      description = ''
        Content to return for requests to this location.
      '';
    };

    root = lib.mkOption {
      type = types.nullOr types.path;
      example = "/path/to/webroot";
      default = null;
      description = ''
        The path of the web root directory.
      '';
    };

    lanOnly = lib.mkEnableOption ''
      Only allow requests from LAN clients.
    '';

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      example = ''
        proxy_buffering off;
      '';
      description = ''
        Extra configs for reverse proxy virtual host.
      '';
    };
  };
}
