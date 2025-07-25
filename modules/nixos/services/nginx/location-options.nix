{ lib, ... }:
let
  types = lib.types;
in
{
  options = {
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

    passthru = lib.mkOption {
      type = with types; attrsOf anything;
      default = { };
      description = "Configurations that are passed through to the nginx vhost location options of the original nixpkgs module.";
    };
  };
}
