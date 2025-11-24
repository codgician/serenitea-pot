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
    "/dev/nvram"
  ];
in
{
  containers.nahida = {
    allowedDevices = builtins.map (node: {
      inherit node;
      modifier = "rw";
    }) gpuDevs;

    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    interfaces = [ "enp67s0f0v1" ];

    path = outputs.nixosConfigurations.nahida.config.system.build.toplevel;
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
    }
    // (lib.genAttrs gpuDevs (node: {
      hostPath = node;
      isReadOnly = false;
    }));
  };
}
