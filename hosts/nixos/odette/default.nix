{
  system = "x86_64-linux";
  roles = [
    "desktop"
    "work"
  ];
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
    ./audio-dsp.nix
  ];
}
