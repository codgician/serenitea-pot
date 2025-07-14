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

    alias = lib.mkOption {
      type = types.nullOr types.path;
      example = "/path/to/alias";
      default = null;
      description = ''
        The path of the alias directory.
      '';
    };

    tryFiles = lib.mkOption {
      type = types.nullOr types.str;
      example = "$uri =404";
      default = null;
      description = "nginx try_files directive.";
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

    ssl = {
      verify = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Enable SSL verification for the reverse proxy.";
      };

      proxySslName = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Enable Proxy ssl server name.";
      };

      trustedCertificate = lib.mkOption {
        type = types.path;
        default = "/etc/ssl/certs/ca-certificates.crt";
        example = "/etc/ssl/certs/mycert.pem";
        description = "Path to the trusted certificate for SSL verification.";
      };
    };

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
