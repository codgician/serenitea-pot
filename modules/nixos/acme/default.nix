{ config, lib, ... }:
let
  cfg = config.codgician.acme;
  types = lib.types;

  # DNS-01 provider of each zone; a certificate uses the zone its name ends in.
  zones = {
    ${lib.codgician.zone} = {
      dnsProvider = "cloudflare";
      credential = "cloudflare-credential";
    };
    "codgi.cn" = {
      dnsProvider = "tencentcloud";
      credential = "tencent-dns-credential";
    };
  };
  zoneOf =
    name:
    lib.findFirst (zone: name == zone || lib.hasSuffix ".${zone}" name) null (lib.attrNames zones);
in
{
  options.codgician.acme = lib.mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          enable = lib.mkEnableOption "ACME certificate auto renew for this domain";

          extraDomainNames = lib.mkOption {
            type = types.listOf types.str;
            example = [
              "example.org"
              "example.net"
            ];
            default = [ ];
            description = ''
              A list of extra domain names, which are included in the one certificate to be issued.
            '';
          };

          reloadServices = lib.mkOption {
            type = types.listOf types.str;
            example = [ "jellyfin" ];
            default = [ ];
            description = ''
              A list of systemd services to call `systemctl try-reload-or-restart` on.
            '';
          };

          postRun = lib.mkOption {
            type = with types; nullOr lines;
            example = "cp full.pem backup.pem";
            default = null;
            description = ''
              Command run after certificate is renewed.
            '';
          };
        };
      }
    );
    default = { };
    description = "Certificates to issue, by primary domain name.";
  };

  config = {
    security.acme = {
      acceptTerms = true;
      useRoot = false;

      certs = lib.mapAttrs (
        name: cert:
        let
          zone = zones.${zoneOf name};
        in
        {
          domain = name;
          email = "codgician@outlook.com";
          environmentFile = config.codgician.secrets.files.${zone.credential}.path;
          inherit (zone) dnsProvider;
          group = with config.services.nginx; lib.mkIf enable user;
          inherit (cert) reloadServices;
          extraDomainNames = lib.lists.unique cert.extraDomainNames;
          postRun = lib.mkIf (cert.postRun != null) cert.postRun;
        }
      ) (lib.filterAttrs (_: cert: cert.enable) cfg);
    };

    assertions = lib.mapAttrsToList (name: _: {
      assertion = zoneOf name != null;
      message = "acme: no DNS challenge provider is known for the zone of ${name}.";
    }) cfg;
  };
}
