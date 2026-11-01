{
  lib,
  pkgs,
  outputs,
  gui ? false,
  ...
}:

# Caution: the produced ISO must NEVER contain any secret. Secrets decrypt into
# RAM only after `rescue unlock` mounts an installed host and verifies its key.
let
  inherit (pkgs.stdenv.hostPlatform) system;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
  mkHost = import ./rescue/host.nix { inherit lib; };
  revision = outputs.shortRev or outputs.dirtyShortRev or "unknown";

  # Every host with disks of its own: the image mounts any architecture (a
  # disk may be moved to another machine); only nixos-enter needs a match.
  hosts = lib.pipe outputs.nixosConfigurations [
    (lib.filterAttrs (_: host: !host.config.boot.isContainer && !(host.config.wsl.enable or false)))
    (lib.mapAttrs (
      name: host:
      mkHost {
        inherit host;
        hostKeys = pubKeys.hosts.${name} or [ ];
      }
    ))
  ];

  isoSystem = lib.codgician.mkNixosSystem {
    hostName = "nixos";
    inherit system;
    modules = [
      (
        { modulesPath, ... }:
        {
          imports = [
            (
              modulesPath
              + "/installer/cd-dvd/installation-cd-${if gui then "graphical-gnome" else "minimal"}.nix"
            )
            (import ./rescue { inherit hosts revision; })
          ];

          # Override to use sudo-rs
          security.sudo.enable = lib.mkForce false;
          security.sudo-rs.enable = lib.mkForce true;

          # Log in as codgi instead of the upstream nixos account. The empty
          # password matches upstream and overrides the users module's default
          # lock; SSH accepts codgi's public keys only.
          users.users.nixos.enable = false;
          users.users.codgi.hashedPassword = "";
          codgician.users.codgi = {
            enable = true;
            extraGroups = [ "networkmanager" ];
          };
          services.getty.autologinUser = lib.mkForce "codgi";
          services.displayManager.autoLogin.user = lib.mkForce "codgi";
          services.getty.helpLine = lib.mkForce ''
            The "codgi" account logs in automatically and sudo needs no password.
            SSH accepts codgi's public keys. To set up Wi-Fi, run `nmtui`.
          '';

          # Deploy only secrets every bootable host can decrypt, so whichever
          # host `rescue unlock` mounts, its key unlocks them all.
          codgician.secrets.hosts = builtins.attrNames hosts;

          # Add common utilities
          environment.systemPackages = with pkgs; [
            inetutils
            htop
            pciutils
            iperf3
            screen
            tmux
            aria2
            sops
            ssh-to-age
            disko
            smartmontools
            acpica-tools
          ];

          home-manager.users.codgi = {
            home.stateVersion = "26.05";
            home.file."serenitea-pot".source = lib.codgician.rootDir;

            codgician.codgi = {
              git.enable = true;
              tmux.enable = true;
              zsh.enable = true;
              oh-my-pi = {
                enable = true;
                context = lib.mkAfter ''
                  This is the serenitea-pot installer and rescue ISO, running from RAM: nothing outside an unlocked host persists across reboots.
                  Installed hosts stay locked until the user runs `rescue unlock <host>` and enters its disk passphrase. Run `rescue status` first: it shows the unlocked host, whether it is read-only, and where its persistent state lives.
                  An unlocked host is mounted at /mnt with its persistent directories bound in place, so its journal is at /mnt/var/log/journal (`journalctl -D`).
                  Read-only is the default. Switching to read-write (`rescue unlock --rw <host>`) needs the passphrase again; then `nixos-enter` and `nixos-install --root /mnt` work if the host shares the ISO's architecture.
                  Disks may have been moved here from another machine, so this machine's own hardware may be unrelated to the unlocked host.
                  ~/serenitea-pot holds the flake this ISO was built from (revision ${revision}); an unlocked host may run a newer revision.
                '';
              };
            };
          };
        }
      )
    ];
  };
in
# Link rather than copy: the image is several GiB.
pkgs.symlinkJoin {
  name = "installer-iso${lib.optionalString gui "-gui"}";
  paths = [ isoSystem.config.system.build.isoImage ];
  meta = {
    description = "NixOS installation and rescue image${lib.optionalString gui " (GNOME)"} customized by codgician";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
