{ ... }: {
  # libvirtd 
  virtualisation.libvirtd = {
    qemu.swtpm.enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    allowedBridges = [ "virbr0" ];
  };

  # Virtual machines
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
    connections."qemu:///system" = {
      domains = [
        { definition = ./openwrt.xml; active = true; }
        { definition = ./hass.xml; active = true; }
      ];

      networks = [{ definition = ./virbr0.xml; active = true; }];
      pools = [{ definition = ./zroot.xml; active = true; }];
    };
  };

  # Add codgi to libvirtd group
  codgician.users.codgi.extraGroups = [ "libvirtd" ];

  # Bridge network for virtual machines
  networking = {
    bridges.virbr0.interfaces = [ "enp4s0" ];
    interfaces.virbr0 = {
      useDHCP = true;
      macAddress = "ac:79:26:f1:5c:81";
    };
  };
}
