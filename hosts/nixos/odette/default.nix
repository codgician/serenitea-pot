{
  system = "x86_64-linux";
  roles = [ "desktop" ];
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
    ./audio-dsp.nix
  ];
}
