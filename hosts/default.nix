{ outputs, ... }:

let
  inherit (outputs) lib;

  # A host folder's `default.nix` is its manifest: `system`, the ordered
  # `modules` list (order decides how list options merge), `roles` shared with
  # other hosts and, on NixOS, `cudaSupport`.
  manifestKeys = [
    "system"
    "cudaSupport"
    "roles"
    "modules"
  ];

  roleModule =
    where: role:
    let
      path = ./roles + "/${role}.nix";
    in
    if builtins.pathExists path then
      path
    else
      throw "${where}: unknown role \"${role}\"; hosts/roles has no ${role}.nix";

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
      mkSystem (
        removeAttrs host [ "roles" ]
        // {
          inherit hostName;
          # A manifest that still lists `roles` also gets `common` and the
          # role of its class.
          modules =
            host.modules
            ++ lib.optionals (host ? roles) (
              map (roleModule where) (
                [
                  "common"
                  class
                ]
                ++ host.roles
              )
            );
        }
      )
    );
in
{
  darwinConfigurations = mkHosts "darwin" lib.codgician.mkDarwinSystem;
  nixosConfigurations = mkHosts "nixos" lib.codgician.mkNixosSystem;
}
