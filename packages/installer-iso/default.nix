{
  lib,
  outputs,
  includeHostDrvs ? false,
  ...
}:

# Caution: produced iso should NEVER contain any secrets
lib.codgician.forLinuxSystems (
  pkgs:
  (
    let
      inherit (pkgs) system;
      hostDrvs = lib.pipe (outputs.nixosConfigurations) [
        (lib.filterAttrs (
          k: v:
          v.pkgs.system == pkgs.system
          && builtins.hasAttr "disko" v.config
          && v.config.disko.devices.disk != { }
        ))
        (lib.mapAttrs (k: v: v.config.system.build.toplevel))
        (builtins.attrValues)
      ];
    in
    lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit system;
      modules = [
        (
          { modulesPath, ... }:
          {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

            # Add common utilities
            environment.systemPackages =
              with pkgs;
              [
                inetutils
                htop
                httplz
                pciutils
                iperf3
                screen
                aria2
                agenix
                disko
                smartmontools
                acpica-tools
                terraform
              ]
              ++ (lib.optional includeHostDrvs hostDrvs);

            # Symlink to source in nixos user home
            home-manager.users.nixos = { ... }: {
              home = {
                stateVersion = "24.11";
                file."serenitea-pot".source = lib.codgician.rootDir;
              };
            };
          }
        )
      ];
    }
  ).config.system.build.isoImage
)
