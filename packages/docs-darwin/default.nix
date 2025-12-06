{
  lib,
  stdenv,
  options ?
    (lib.codgician.mkDarwinSystem {
      hostName = "darwin";
      inherit (stdenv.hostPlatform) system;
    }).options,
  docs-nixos,
  ...
}:

docs-nixos.override { inherit options; }
