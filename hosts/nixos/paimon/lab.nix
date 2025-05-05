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
      "/persist" = {
        hostPath = "/zroot/lab";
        isReadOnly = false;
      };
    } // (lib.genAttrs gpuDevs (node: {
      hostPath = node;
      isReadOnly = false;
    }));
  };
}
