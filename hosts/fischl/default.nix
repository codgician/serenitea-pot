{ inputs, ... }: {
  system = "x86_64-linux";
  modules = [
    ./disks.nix
    ./hardware.nix
    ./system.nix
    ./vms
  ];
}
