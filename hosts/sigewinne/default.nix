{ inputs, ... }: {
  system = "aarch64-linux";
  modules = [
    ./hardware.nix
    ./system.nix
    ./tpm.nix
  ];
  nixpkgs = inputs.nixpkgs-nixos-unstable;
  home-manager = inputs.home-manager-unstable;
}
