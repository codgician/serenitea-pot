{ config, lib, ... }: {
  imports = [
    ./zones
    ./providers.nix
  ];
}
