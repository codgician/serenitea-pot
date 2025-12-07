{
  lib,
  pkgs,
  stdenv,
  inetutils,
  htop,
  pciutils,
  iperf3,
  screen,
  aria2,
  agenix,
  disko,
  smartmontools,
  acpica-tools,
  terraform,

  # options
  extraModules ? [ ],
  ...
}:

# Caution: produced iso should NEVER contain any secrets
let
  isoImage =
    (lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        (
          { modulesPath, ... }:
          {
            imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

            # Override to use sudo-rs
            security.sudo.enable = lib.mkForce false;
            security.sudo-rs.enable = lib.mkForce true;

            # Allow password auth for openssh
            services.openssh.settings.PasswordAuthentication = lib.mkForce true;

            # Add common utilities
            environment.systemPackages = [
              inetutils
              htop
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
                  stateVersion = "25.11";
                  file."serenitea-pot".source = lib.codgician.rootDir;
                };
              };
          }
        )
      ]
      ++ extraModules;
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
