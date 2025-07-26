{ lib, ... }:
let
  types = lib.types;
in
{
  options = {
    lanOnly = lib.mkEnableOption ''
      Only allow requests from LAN clients.
    '';

    authelia = {
      enable = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Authelia authentication for this location.
          This is only effective when authelia is enabled in the vhost.
        '';
      };

      policy = lib.mkOption {
        type =
          with types;
          nullOr (enum [
            "bypass"
            "one_factor"
            "two_factor"
          ]);
        default = null;
        description = ''
          Override the authentication policy for this location.
          If null, uses the vhost default policy.
        '';
      };
    };

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
