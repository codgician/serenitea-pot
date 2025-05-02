{
  config,
  lib,
  pkgs,
  ...
}:
let
  domains = import ./domains.nix;
  domainNames = builtins.attrNames domains;
  cfg = config.codgician.acme;
  types = lib.types;

  # Define module options for each certificate
  mkAcmeOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable ACME certificate auto renew for domain "${name}".'';

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

      ageSecretFilePath = lib.mkOption {
        type = types.nullOr types.path;
        internal = true;
        visible = false;
        default = null;
        description = ''
          Path to the age secret file for retrieving the certificate.
        '';
      };
    };
  };

  # Define configurations for each certificate
  mkAcmeConfig =
    name:
    lib.mkIf cfg.${name}.enable (
      lib.mkMerge [
        # Import domain-specific settings
        (import domains.${name}.challengeProfile {
          domain = name;
          inherit config lib pkgs;
        })

        # Generic configs
        {
          security.acme.certs.${name} = {
            domain = name;
            inherit (cfg.${name}) reloadServices;
            extraDomainNames = lib.lists.unique cfg.${name}.extraDomainNames;
            postRun = with cfg.${name}; lib.mkIf (postRun != null) postRun;
          };
        }
      ]
    );
in
{
  options.codgician.acme = lib.codgician.concatAttrs (builtins.map mkAcmeOptions domainNames);
  config = lib.mkMerge (
    (builtins.map mkAcmeConfig domainNames)
    ++ [
      # Accept terms
      {
        security.acme = {
          acceptTerms = true;
          useRoot = false;
        };
      }

      # Agenix credentials
      (lib.codgician.mkAgenixConfigs { } (
        lib.pipe domainNames [
          (builtins.filter (name: cfg.${name}.enable && cfg.${name}.ageSecretFilePath != null))
          (builtins.map (name: cfg.${name}.ageSecretFilePath))
          lib.lists.unique
        ]
      ))
    ]
  );
}
