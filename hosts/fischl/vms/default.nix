{ config, ... }: {
  imports = [
    ./hass.nix
    ./openwrt.nix
  ];

  # Enable libvirtd
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
  };

  # Add codgi to libvirtd group
  codgician.users.codgi.extraGroups = [ "libvirtd" ];

  # Add bridge network for virtual machines
  networking = {
    bridges.vmbr0.interfaces = [ "enp4s0" ];
    interfaces.vmbr0 = {
      useDHCP = true;
      macAddress = "ac:79:26:f1:5c:81";
    };
  };
}
