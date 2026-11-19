{ outputs, ... }:

let
  inherit (outputs) lib;

  # A host folder's `default.nix` is its manifest: `system`, the ordered
  # `modules` list (order decides how list options merge) and, on NixOS,
  # `cudaSupport`.
  manifestKeys = [
    "system"
    "cudaSupport"
    "modules"
  ];

  mkHosts =
    class: mkSystem:
    lib.genAttrs (lib.codgician.getFolderNames (./. + "/${class}")) (
      hostName:
      let
        where = "hosts/${class}/${hostName}";
        host = import (./. + "/${class}/${hostName}");
        unknown = lib.attrNames (removeAttrs host manifestKeys);
      in
      assert lib.assertMsg (unknown == [ ]) "${where}: unknown manifest attributes: ${toString unknown}";
      mkSystem (host // { inherit hostName; })
    );
in
{
  darwinConfigurations = mkHosts "darwin" lib.codgician.mkDarwinSystem;
  nixosConfigurations = mkHosts "nixos" lib.codgician.mkNixosSystem;
}
