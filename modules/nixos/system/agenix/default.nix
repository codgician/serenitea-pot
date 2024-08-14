{ config, lib, ... }:
let
  cfg = config.codgician.system.agenix;
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.agenix = {
    hostIdentityPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ "/etc/ssh/ssh_host_ed25519_key" ];
      description = "Host identity (ssh public keys) paths.";
    };
  };

  # Workaround impermanence
  config.age.identityPaths =
    if impermanenceCfg.enable
    then builtins.map (x: impermanenceCfg.path + x) cfg.hostIdentityPaths
    else cfg.hostIdentityPaths;
}
