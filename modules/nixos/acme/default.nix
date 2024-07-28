{ config, lib, pkgs, ... }:
let
  domains = import ./domains.nix;
  domainNames = builtins.attrNames domains;
  cfg = config.codgician.acme;
  systemCfg = config.codgician.system;
  types = lib.types;

  # Define module options for each certificate
  mkAcmeOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable ACME certificate auto renew for domain "${name}".'';

      extraDomainNames = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.org" "example.net" ];
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

      postRunScripts = lib.mkOption {
        type = types.listOf types.lines;
        example = [ "cp full.pem backup.pem" ];
        default = [ ];
        description = ''
          List of commands to run after certificate is renewed. Each command is run in a separate bash shell.
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
  mkAcmeConfig = name: lib.mkIf cfg.${name}.enable (lib.mkMerge [
    # Import domain-specific settings
    (import domains.${name}.challengeProfile { domain = name; inherit config lib pkgs; })

    # Generic configs
    {
      security.acme.certs.${name} = {
        domain = name;
        extraDomainNames = lib.lists.unique cfg.${name}.extraDomainNames;
        reloadServices = cfg.${name}.reloadServices;
        postRun =
          let
            commands = builtins.map (x: "${pkgs.bash}/bin/bash -c '${x}'") cfg.${name}.postRunScripts;
          in
          builtins.concatStringsSep "\n" commands;
      };
    }
  ]);
in
rec {
  options.codgician.acme = lib.codgician.concatAttrs (builtins.map mkAcmeOptions domainNames);
  config = lib.mkMerge ((builtins.map mkAcmeConfig domainNames) ++ [
    # Accept terms
    {
      security.acme = {
        acceptTerms = true;
        useRoot = false;
      };
    }

    # Agenix credentials
    (
      let
        secrets = lib.lists.unique (
          builtins.map (name: cfg.${name}.ageSecretFilePath) (
            builtins.filter (name: cfg.${name}.enable && cfg.${name}.ageSecretFilePath != null) domainNames));
      in
      lib.codgician.mkAgenixConfigs "root" secrets
    )
  ]);
}
