{
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    allowedBridges = [ "vs0" ];
    startDelay = 3;
  };

  # NixVirt applies the domains, networks and pools a host declares.
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
  };

  codgician = {
    users.codgi.extraGroups = [ "libvirtd" ];

    system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/libvirt";
      }
      {
        type = "directory";
        path = "/var/lib/swtpm-localca";
      }
    ];
  };
}
