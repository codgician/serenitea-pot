{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.system.agenix;
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.agenix = {
    enable = lib.mkEnableOption "Enable agenix for secrets management.";
    hostIdentityPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key"
      ];
      description = "Host identity (ssh public keys) paths.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install agenix CLI
    environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.default ];

    # Workaround impermanence
    age.identityPaths =
      if impermanenceCfg.enable
      then builtins.map (x: impermanenceCfg.path + x) cfg.hostIdentityPaths
      else cfg.hostIdentityPaths;

    # Assertions
    assertions = [
      (
        let
          badIdentities = builtins.filter (x: !builtins.elem x impermanenceCfg.files) cfg.hostIdentityPaths;
        in
        {
          assertion = !impermanenceCfg.enable || (builtins.length badIdentities == 0);
          message = "Following host identities are not persisted by impermanence:\n '${builtins.concatStringsSep "'\n '" badIdentities}'";
        }
      )
    ];
  };
}
