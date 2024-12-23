{ pkgs, ... }: {
  # libvirtd 
  virtualisation.libvirtd = {
    qemu.swtpm.enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    allowedBridges = [ "virbr0" ];
    hooks.qemu = {
      "10-isolate-cpu" = pkgs.writeShellApplication {
        name = "qemu-hook";
        runtimeInputs = with pkgs; [ systemd ];
        text = ''
          vm=$1
          command=$2
          if [ "$vm" != "openwrt" ]; then
            echo "Skip running hook script for vm $vm"
            exit 0
          fi

          if [ "$command" = "started" ]; then
            echo "Limiting host CPU cores to 0,1,6,7"
            systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,6,7
            systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,6,7
            systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,6,7
          elif [ "$command" = "release" ]; then
            echo "Releasing isolated CPU cores"
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-7
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-7
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-7
          fi
        '';
      };
    };
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
