{
  system = "x86_64-linux";
  roles = [
    "desktop"
    "work"
  ];
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
    ./audio-dsp.nix
  ];
}
