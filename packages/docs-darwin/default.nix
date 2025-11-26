{
  lib,
  pkgs,
  options ?
    (lib.codgician.mkDarwinSystem {
      hostName = "darwin";
      inherit (pkgs.stdenv.hostPlatform) system;
    }).options,
  docs-nixos,
  ...
}:

docs-nixos.override { inherit options; }
