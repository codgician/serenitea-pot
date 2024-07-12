{ inputs, ... }: {
  system = "aarch64-linux";
  modules = [
    ./hardware.nix
    ./system.nix
    ./tpm.nix
  ];
}
