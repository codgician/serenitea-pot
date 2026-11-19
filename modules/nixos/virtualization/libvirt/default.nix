{ config, lib, ... }:
let
  cfg = config.codgician.virtualization.libvirt;
in
{
  options.codgician.virtualization.libvirt.enable =
    lib.mkEnableOption "the libvirt host: libvirtd with swtpm, and NixVirt for the domains, networks and pools the host declares";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
      onBoot = "start";
      onShutdown = "shutdown";
      allowedBridges = [ "vs0" ];
      startDelay = 3;
    };

    virtualisation.libvirt = {
      enable = true;
      swtpm.enable = true;
    };

    # The hosts persist /var/lib/libvirt and /var/lib/swtpm-localca themselves:
    # listed here they would merge ahead of every other persisted directory.
  };
}
