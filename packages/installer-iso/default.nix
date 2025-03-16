{ lib, pkgs, ... }:

# Caution: produced iso should NEVER contain any secrets
(lib.codgician.mkNixosSystem {
  hostName = "nixos";
  inherit (pkgs) system;
  modules = [
    (
      { modulesPath, ... }:
      {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

        # Add common utilities
        environment.systemPackages = with pkgs; [
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
        ];

        # Symlink to source in nixos user home
        home-manager.users.nixos =
          { ... }:
          {
            home = {
              stateVersion = "24.11";
              file."serenitea-pot".source = lib.codgician.rootDir;
            };
          };
      }
    )
  ];
}).config.system.build.isoImage.overrideAttrs
  (oldAttrs: {
    meta = {
      description = "NixOS installation image customized by codgician";
      platforms = lib.platforms.linux;
      license = lib.licenses.mit;
    };
  })
