{ lib, pkgs, ... }:
{
  # libvirtd
  virtualisation.libvirtd = {
    qemu.swtpm.enable = true;
    onBoot = "start";
    onShutdown = "shutdown";
    allowedBridges = [ "vs0" ];
    startDelay = 3;
    hooks.qemu = {
      "10-isolate-cpu" = lib.getExe (
        pkgs.writeShellApplication {
          name = "qemu-hook";
          runtimeInputs = with pkgs; [ systemd ];
          text = ''
            vm=$1
            command=$2
            if [ "$vm" != "openwrt" ]; then
              exit 0
            fi

            if [ "$command" = "started" ]; then
              systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,6,7
              systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,6,7
              systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,6,7
            elif [ "$command" = "release" ]; then
              systemctl set-property --runtime -- system.slice AllowedCPUs=0-7
              systemctl set-property --runtime -- user.slice AllowedCPUs=0-7
              systemctl set-property --runtime -- init.scope AllowedCPUs=0-7
            fi
          '';
        }
      );
    };
  };

  # Virtual machines
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
    connections."qemu:///system" = {
      domains = [
        {
          definition = ./openwrt.xml;
          active = true;
        }
        {
          definition = ./hass.xml;
          active = true;
        }
      ];

      networks = [
        {
          definition = ./vs0.xml;
          active = true;
        }
      ];
      pools = [
        {
          definition = ./zroot.xml;
          active = true;
        }
      ];
    };
  };

  # Add codgi to libvirtd group
  codgician.users.codgi.extraGroups = [ "libvirtd" ];

  # Bridge network for virtual machines
  codgician.virtualization.vswitch = {
    enable = true;
    switches.vs0 = {
      interfaces.enp4s0 = {
        type = "dpdk";
        device = "0000:04:00.0";
      };
      macAddress = "ac:79:26:f1:5c:81";
    };
  };
  networking.interfaces.vs0.useDHCP = true;
}
