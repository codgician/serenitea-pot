{ pkgs, lib, ... }:
{
  # OVMFFull with MS Secure Boot keys at /run/libvirt/nix-ovmffull/
  systemd.services.libvirtd-config = {
    serviceConfig.RuntimeDirectory = [ "libvirt/nix-ovmffull" ];
    script = lib.mkAfter ''
      cp -sf ${pkgs.OVMFFull.fd}/FV/* /run/libvirt/nix-ovmffull/
    '';
  };

  # libvirtd
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
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
            if [ "$vm" != "alhaitham" ]; then
              exit 0
            fi

            if [ "$command" = "started" ]; then
              systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
              systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
              systemctl set-property --runtime -- init.scope AllowedCPUs=0-11
            elif [ "$command" = "release" ]; then
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
    enable = true;
    swtpm.enable = true;
    connections."qemu:///system" = {
      domains = [
        {
          definition = ./alhaitham.xml;
          active = false;
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

  # Add codgi to libvirtd and kvm groups (kvm needed for /dev/kvmfr0 access)
  codgician.users.codgi.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  # Impermanence for libvirt and swtpm state
  codgician.system.impermanence.extraItems = [
    {
      type = "directory";
      path = "/var/lib/libvirt";
    }
    {
      type = "directory";
      path = "/var/lib/swtpm-localca";
    }
  ];
}
