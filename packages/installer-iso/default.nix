{
  lib,
  pkgs,
  stdenv,
  inetutils,
  htop,
  httplz,
  pciutils,
  iperf3,
  screen,
  aria2,
  agenix,
  disko,
  smartmontools,
  acpica-tools,
  terraform,
  ...
}:

# Caution: produced iso should NEVER contain any secrets
let
  isoImage =
    (lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit (pkgs) system;
      modules = [
        (
          { modulesPath, ... }:
          {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

            # Override to use sudo-rs
            security.sudo.enable = lib.mkForce false;
            security.sudo-rs.enable = lib.mkForce true;

            # Add common utilities
            environment.systemPackages = [
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
                  stateVersion = "25.05";
                  file."serenitea-pot".source = lib.codgician.rootDir;
                };
              };
          }
        )
      ];
    }).config.system.build.isoImage;
in
stdenv.mkDerivation {
  pname = "installer-iso";
  version = pkgs.lib.version;
  src = isoImage;
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out
    cp -r $src $out
  '';
  meta = {
    description = "NixOS installation image customized by codgician";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
