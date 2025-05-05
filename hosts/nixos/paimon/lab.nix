{ ... }:
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
    interfaces = [ "enp67s0f0v1" ];

    config = { lib, ... }: { 
      boot.isContainer = true; 
      networking = {
        hostName = "nahida";
        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;
        useNetworkd = true;
      };
      services.resolved.enable = true;
      system.stateVersion = "24.11";
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
  };
}
