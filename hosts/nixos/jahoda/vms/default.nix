{ pkgs, lib, ... }:
{
  codgician.virtualization.libvirt.enable = true;

  # OVMFFull with MS Secure Boot keys at /run/libvirt/nix-ovmffull/
  systemd.services.libvirtd-config = {
    serviceConfig.RuntimeDirectory = [ "libvirt/nix-ovmffull" ];
    script = lib.mkAfter ''
      cp -sf ${pkgs.OVMFFull.fd}/FV/* /run/libvirt/nix-ovmffull/
    '';
  };

  # libvirtd
  virtualisation.libvirtd = {
    allowedBridges = [ "vs0" ];
    qemu = {
      vhostUserPackages = with pkgs; [ virtiofsd ];
      verbatimConfig = ''
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm",
          "/dev/kvmfr0"
        ]
      '';
    };
    hooks.qemu = {
      "10-isolate-cpu" = lib.getExe (
        pkgs.writeShellApplication {
          name = "qemu-hook";
          runtimeInputs = with pkgs; [ systemd ];
          text = ''
            vm=$1
            command=$2
            if [ "$vm" != "alhaitham" ]; then
              exit 0
            fi

            if [ "$command" = "started" ]; then
              systemctl set-property --runtime -- machine.slice AllowedCPUs=0-11
              systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
              systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
              systemctl set-property --runtime -- init.scope AllowedCPUs=0-11
            elif [ "$command" = "release" ]; then
              systemctl set-property --runtime -- machine.slice AllowedCPUs=0-19
              systemctl set-property --runtime -- system.slice AllowedCPUs=0-19
              systemctl set-property --runtime -- user.slice AllowedCPUs=0-19
              systemctl set-property --runtime -- init.scope AllowedCPUs=0-19
            fi
          '';
        }
      );
    };
  };

  # Virtual machines
  virtualisation.libvirt = {
    connections."qemu:///system" = {
      domains = [
        {
          definition = ./alhaitham.xml;
          active = true;
        }
      ];
      networks = [
        {
          definition = ./virbr0.xml;
          active = true;
        }
      ];
      pools = [
        {
          definition = ./vm-storage.xml;
          active = true;
        }
      ];
    };
  };

  # kvm grants access to /dev/kvmfr0
  codgician.users.codgi.extraGroups = [ "kvm" ];
}
