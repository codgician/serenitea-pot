{ outputs, ... }:

let
  inherit (outputs) lib;
  inherit (lib.codgician) inventory;

  classOf = host: if lib.hasSuffix "-darwin" host.system then "darwin" else "nixos";
  hostsOf = class: lib.filterAttrs (_: host: classOf host == class) inventory.hosts;

  # A host is the module list in its directory's `default.nix`, followed by
  # the roles shared with other hosts: `common`, its class, and those the
  # inventory assigns.
  modulesFor =
    class: name: host:
    import (./. + "/${class}/${name}")
    ++ map (role: ./roles + "/${role}.nix") (
      [
        "common"
        class
      ]
      ++ host.roles or [ ]
    );
in
{
  darwinConfigurations = lib.mapAttrs (
    name: host:
    lib.codgician.mkDarwinSystem {
      hostName = name;
      inherit (host) system;
      modules = modulesFor "darwin" name host;
    }
  ) (hostsOf "darwin");

  nixosConfigurations = lib.mapAttrs (
    name: host:
    lib.codgician.mkNixosSystem {
      hostName = name;
      inherit (host) system;
      cudaSupport = host.cudaSupport or false;
      modules = modulesFor "nixos" name host;
    }
  ) (hostsOf "nixos");
}
