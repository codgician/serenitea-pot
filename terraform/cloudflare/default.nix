{ config, lib, ... }: {
  imports = [
    ./providers.nix
    ./zones.nix
  ];
}
