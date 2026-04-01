# Impermanence wipe-on-shutdown integration tests
{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:

let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
  system = pkgs.stdenv.hostPlatform.system;

  commonDefaults = {
    imports = lib.codgician.mkNixosModules system { };
    nixpkgs.overlays = pkgs.overlays;
    _module.args = {
      inherit inputs outputs system;
    };
  };

  machineBase =
    { lib, pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      users.users.root = {
        initialPassword = "root";
        hashedPasswordFile = lib.mkForce null;
      };

      virtualisation = {
        emptyDiskImages = [ 4096 ];
        useBootLoader = true;
        useEFIBoot = true;
        fileSystems."/persist" = {
          device = "testpool/persist";
          fsType = "zfs";
          neededForBoot = true;
          options = [
            "nofail"
            "x-systemd.device-timeout=1"
          ];
        };
      };

      boot = {
        loader.systemd-boot.enable = true;
        loader.timeout = 0;
        loader.efi.canTouchEfiVariables = true;
        supportedFilesystems = [ "zfs" ];
        zfs.devNodes = "/dev/disk/by-uuid";
        zfs.forceImportAll = true;
        initrd.systemd.enable = true;
      };

      networking.hostId = "deadbeef";
      environment.systemPackages = [
        pkgs.parted
        pkgs.findutils
      ];

      codgician.system.impermanence = {
        enable = true;
        wipeOnShutdown.zfs = {
          enable = true;
          datasets = [ "testpool/root" ];
        };
      };
    };

  # Btrfs machine base for btrfs wipe-on-shutdown tests
  btrfsMachineBase =
    { lib, pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      users.users.root = {
        initialPassword = "root";
        hashedPasswordFile = lib.mkForce null;
      };

      virtualisation = {
        emptyDiskImages = [ 4096 ];
        useBootLoader = true;
        useEFIBoot = true;
        # No fileSystems./persist — we create btrfs subvolumes in test
      };

      boot = {
        loader.systemd-boot.enable = true;
        loader.timeout = 0;
        loader.efi.canTouchEfiVariables = true;
        supportedFilesystems = [ "btrfs" ];
        initrd.systemd.enable = true;
      };

      environment.systemPackages = [
        pkgs.parted
        pkgs.btrfs-progs
        pkgs.findutils
      ];

      codgician.system.impermanence = {
        enable = true;
        wipeOnShutdown.btrfs = {
          enable = true;
          subvolumes = [
            {
              device = "/dev/vdb1";
              subvolume = "root";
            }
          ];
        };
      };
    };

in
{
  # Normal path: rollback to existing @empty
  wipeOnShutdown = nixos-lib.runTest {
    name = "impermanence-wipe-on-shutdown";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machineBase;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup ZFS pool with @empty"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkdir -p /etc/zfs",
              "zpool create -f -o cachefile=/etc/zfs/zpool.cache testpool /dev/vdb1",
              "zfs create -o mountpoint=/testroot testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
              "zfs snapshot testpool/root@empty",
          )

      with subtest("Add ephemeral and persistent data"):
          machine.succeed(
              "mkdir -p /testroot/ephemeral",
              "echo 'ephemeral' > /testroot/ephemeral/file.txt",
              "mkdir -p /persist/important",
              "echo 'persistent' > /persist/important/file.txt",
              "sync",
          )
          machine.succeed("test -f /testroot/ephemeral/file.txt")

      with subtest("Reboot and verify wipe"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("zfs mount testpool/root || true")
          machine.fail("test -f /testroot/ephemeral/file.txt")
          machine.succeed("test -f /persist/important/file.txt")
          machine.succeed("zfs list -t snapshot testpool/root@empty")
    '';
  };

  # Bootstrap path: create @empty when missing
  wipeOnShutdownBootstrap = nixos-lib.runTest {
    name = "impermanence-wipe-on-shutdown-bootstrap";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machineBase;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup ZFS pool without @empty"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkdir -p /etc/zfs",
              "zpool create -f -o cachefile=/etc/zfs/zpool.cache testpool /dev/vdb1",
              "zfs create -o mountpoint=/testroot testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )
          machine.succeed(
              "mkdir -p /testroot/old-data",
              "echo 'old' > /testroot/old-data/file.txt",
              "mkdir -p /persist/important",
              "echo 'persistent' > /persist/important/file.txt",
              "sync",
          )
          machine.fail("zfs list -t snapshot testpool/root@empty")

      with subtest("Reboot to trigger bootstrap"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify bootstrap created @empty and wiped data"):
          machine.succeed("zfs list -t snapshot testpool/root@empty")
          machine.succeed("zfs mount testpool/root || true")
          machine.fail("test -f /testroot/old-data/file.txt")
          machine.succeed("test -f /persist/important/file.txt")
          output = machine.succeed("zfs get -H -o value mountpoint testpool/root")
          assert output.strip() == "/testroot", f"Expected /testroot, got {output.strip()}"

      with subtest("Subsequent reboot uses normal rollback"):
          machine.succeed(
              "mkdir -p /testroot/new-session",
              "echo 'new' > /testroot/new-session/file.txt",
              "sync",
          )
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("zfs mount testpool/root || true")
          machine.fail("test -f /testroot/new-session/file.txt")
    '';
  };

  # Btrfs normal path: rollback to existing @empty snapshot
  wipeOnShutdownBtrfs = nixos-lib.runTest {
    name = "impermanence-wipe-on-shutdown-btrfs";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = btrfsMachineBase;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup btrfs with @empty snapshot"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkfs.btrfs -f /dev/vdb1",
              "mkdir -p /mnt",
              "mount /dev/vdb1 /mnt",
              "btrfs subvolume create /mnt/root",
              "btrfs subvolume create /mnt/persist",
              "btrfs subvolume snapshot /mnt/root /mnt/root@empty",
              "umount /mnt",
          )

      with subtest("Mount subvolumes and add ephemeral data"):
          machine.succeed(
              "mkdir -p /testroot /persist",
              "mount -o subvol=root /dev/vdb1 /testroot",
              "mount -o subvol=persist /dev/vdb1 /persist",
              "mkdir -p /testroot/ephemeral",
              "echo 'ephemeral' > /testroot/ephemeral/file.txt",
              "mkdir -p /persist/important",
              "echo 'persistent' > /persist/important/file.txt",
              "sync",
          )
          machine.succeed("test -f /testroot/ephemeral/file.txt")

      with subtest("Reboot and verify wipe"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")
          # Re-mount to check
          machine.succeed(
              "mkdir -p /testroot /persist",
              "mount -o subvol=root /dev/vdb1 /testroot || true",
              "mount -o subvol=persist /dev/vdb1 /persist || true",
          )
          machine.fail("test -f /testroot/ephemeral/file.txt")
          machine.succeed("test -f /persist/important/file.txt")
          # Verify @empty snapshot still exists
          machine.succeed(
              "mount /dev/vdb1 /mnt",
              "btrfs subvolume list /mnt | grep 'root@empty'",
              "umount /mnt",
          )
    '';
  };

  # Btrfs bootstrap path: create @empty when missing
  wipeOnShutdownBtrfsBootstrap = nixos-lib.runTest {
    name = "impermanence-wipe-on-shutdown-btrfs-bootstrap";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = btrfsMachineBase;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup btrfs without @empty snapshot"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkfs.btrfs -f /dev/vdb1",
              "mkdir -p /mnt",
              "mount /dev/vdb1 /mnt",
              "btrfs subvolume create /mnt/root",
              "btrfs subvolume create /mnt/persist",
              # Note: NOT creating @empty snapshot
              "umount /mnt",
          )

      with subtest("Mount and add old data"):
          machine.succeed(
              "mkdir -p /testroot /persist",
              "mount -o subvol=root /dev/vdb1 /testroot",
              "mount -o subvol=persist /dev/vdb1 /persist",
              "mkdir -p /testroot/old-data",
              "echo 'old' > /testroot/old-data/file.txt",
              "mkdir -p /persist/important",
              "echo 'persistent' > /persist/important/file.txt",
              "sync",
          )
          # Verify @empty does NOT exist
          machine.succeed("mount /dev/vdb1 /mnt")
          machine.fail("btrfs subvolume list /mnt | grep 'root@empty'")
          machine.succeed("umount /mnt")

      with subtest("Reboot to trigger bootstrap"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify bootstrap created @empty and wiped data"):
          machine.succeed(
              "mount /dev/vdb1 /mnt",
              "btrfs subvolume list /mnt | grep 'root@empty'",
              "umount /mnt",
          )
          machine.succeed(
              "mkdir -p /testroot /persist",
              "mount -o subvol=root /dev/vdb1 /testroot || true",
              "mount -o subvol=persist /dev/vdb1 /persist || true",
          )
          machine.fail("test -f /testroot/old-data/file.txt")
          machine.succeed("test -f /persist/important/file.txt")

      with subtest("Subsequent reboot uses normal rollback"):
          machine.succeed(
              "mkdir -p /testroot/new-session",
              "echo 'new' > /testroot/new-session/file.txt",
              "sync",
          )
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")
          machine.succeed(
              "mkdir -p /testroot",
              "mount -o subvol=root /dev/vdb1 /testroot || true",
          )
          machine.fail("test -f /testroot/new-session/file.txt")
    '';
  };
}
