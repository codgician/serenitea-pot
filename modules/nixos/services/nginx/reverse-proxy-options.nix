{ config, lib, ... }: 
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

    lanOnly = lib.mkEnableOption ''
      Only allow requests from LAN clients.
    '';
  };
}