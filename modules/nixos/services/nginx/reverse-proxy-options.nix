{ lib, ... }:
let
  types = lib.types;
in
{
  options = {
    enable = lib.mkEnableOption ''
      Enable nginx reverse proxy profile for this service.
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

    proxyPass = lib.mkOption {
      type = types.str;
      example = "http://localhost:8080";
      description = lib.mdDoc ''
        Target URI of reverse proxy.
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
      description = lib.mdDoc ''
        Extra configs for reverse proxy virtual host.
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
