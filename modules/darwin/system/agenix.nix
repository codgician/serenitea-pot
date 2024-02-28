{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.system.agenix;
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.agenix = {
    enable = lib.mkEnableOption "Enable agenix for secrets management.";
  };

  config = lib.mkIf cfg.enable {
    # Install agenix CLI
    environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.default ];
  };
}
