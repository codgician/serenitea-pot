{ outputs, lib, ... }:
let
  gpuDevs = [
    # GPU
    "/dev/dri"
    "/dev/shm"
    "/dev/nvidia-uvm"
    "/dev/nvidia-uvm-tools"
    "/dev/nvidia0"
    "/dev/nvidiactl"
  ];
  nahida = outputs.nixosConfigurations.nahida.config;
in
{
  # Authelia builds its rules from the sites paimon knows; this one is
  # declared in nahida's files.
  codgician.services.nginx.reverseProxies.dsh-web = {
    inherit (nahida.codgician.services.nginx.reverseProxies.dsh-web) domains authelia;
  };

  containers.nahida = {
    allowedDevices = builtins.map (node: {
      inherit node;
      modifier = "rw";
    }) gpuDevs;

    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "enp193s0f0v1" ];

    path = nahida.system.build.toplevel;
    bindMounts = {
      "/lab" = {
        hostPath = "/fpool/lab";
        isReadOnly = false;
      };

      "/persist" = {
        hostPath = "/zroot/lab";
        isReadOnly = false;
      };

      # There could be information leakage, but acceptable
      # because we only run trusted code inside container.
      "/nix/var/log/nix" = {
        hostPath = "/nix/var/log/nix";
        isReadOnly = true;
      };
      "/nix/var/nix/builds" = {
        hostPath = "/nix/var/nix/builds";
        isReadOnly = true;
      };
    }
    // (lib.genAttrs gpuDevs (node: {
      hostPath = node;
      isReadOnly = false;
    }));
  };
}
