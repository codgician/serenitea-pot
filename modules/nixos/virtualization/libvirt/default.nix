{ config, lib, ... }:
let
  cfg = config.codgician.virtualization.libvirt;
  systemCfg = config.codgician.system;
  types = lib.types;
in
{
  options.codgician.virtualization.libvirt.enable = lib.mkEnableOption ''
    Enable libvirt.
  '';

  config = lib.mkIf cfg.enable {
    virtualisation = {
      libvirt = {
        enable = true;
        swtpm.enable = true;
      };
    };
  };
}
