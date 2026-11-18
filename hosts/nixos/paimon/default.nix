[
  ./system.nix
  (import ./disks.nix { })
  ./hardware.nix
  ./network.nix
  ./lab.nix
  ./proxmox.nix
  ./monitoring.nix
]
