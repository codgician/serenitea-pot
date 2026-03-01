# Impermanence module integration tests
#
# These tests verify the initrd impermanence service by:
# 1. Creating a ZFS pool on a separate disk during first boot
# 2. Configuring the pool to be imported via boot.zfs.extraPools
# 3. Rebooting and letting the initrd service run
# 4. Verifying the wipe/rollback worked
#
# Note: The ZFS pool is created at runtime in the test, then the VM reboots.
# The filesystem config uses nofail to allow the first boot to succeed
# without the pool existing yet.
{
  lib,
  pkgs,
  ...
}:

let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

  commonDefaults = {
    imports = lib.codgician.mkNixosModules pkgs.stdenv.hostPlatform.system { };
    nixpkgs.overlays = pkgs.overlays;
  };

  # Machine config with impermanence enabled
  machine =
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
        # Add ZFS filesystem to virtualisation.fileSystems so it's included in VM config
        # This ensures zfs-import-testpool.service is created in initrd
        fileSystems."/persist" = {
          device = "testpool/persist";
          fsType = "zfs";
          neededForBoot = true;
          # nofail allows first boot without pool, x-systemd.device-timeout prevents long waits
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
      environment.systemPackages = [ pkgs.parted ];

      codgician.system.impermanence = {
        enable = true;
        wipeOnBoot.zfs = {
          enable = true;
          datasets = [ "testpool/root" ];
        };
      };
    };
in
{
  # Integration test: Normal path with actual reboot
  # Tests that the initrd service correctly rolls back to @blank
  wipeOnBoot = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machine;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup ZFS pool"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkdir -p /etc/zfs",
              "zpool create -f -o cachefile=/etc/zfs/zpool.cache testpool /dev/vdb1",
              "zfs create -o mountpoint=legacy testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )

      with subtest("Create @blank snapshot"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "zfs snapshot testpool/root@blank",
              "umount /mnt/root",
          )

      with subtest("Add ephemeral data after @blank"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/ephemeral",
              "echo 'ephemeral data' > /mnt/root/ephemeral/file.txt",
              "sync",
              "umount /mnt/root",
          )

      with subtest("Add persistent data"):
          machine.succeed(
              "mkdir -p /persist/important",
              "echo 'persistent data' > /persist/important/file.txt",
              "sync",
          )

      with subtest("Verify ephemeral data exists before reboot"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.succeed("test -f /mnt/root/ephemeral/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Reboot to trigger initrd impermanence service"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify impermanence service ran successfully"):
          print(machine.succeed("journalctl -b | grep -i 'zfs\|testpool\|impermanence' | head -80 || true"))
          print(machine.succeed("zpool list || true"))
          print(machine.succeed("journalctl -b -u impermanence-wipe-zfs.service 2>&1 || true"))
          machine.succeed("journalctl -b -u impermanence-wipe-zfs.service | grep -q 'Rolling back'")

      with subtest("Verify ephemeral data was wiped"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/ephemeral/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Verify only @blank snapshot exists"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")
          output = machine.succeed("zfs list -t snapshot -H -o name testpool/root | wc -l")
          assert output.strip() == "1", f"Expected 1 snapshot, got {output.strip()}"

      with subtest("Verify persistent data survived"):
          machine.succeed("test -f /persist/important/file.txt")

      with subtest("Verify no @last snapshot exists (normal path)"):
          machine.fail("zfs list -t snapshot testpool/root@last")
    '';
  };

  # Integration test: Bootstrap path with actual reboot
  # Tests that the initrd service creates @last backup and @blank
  wipeOnBootBootstrap = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot-bootstrap";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machine;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Setup ZFS pool with existing data (no @blank)"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "mkdir -p /etc/zfs",
              "zpool create -f -o cachefile=/etc/zfs/zpool.cache testpool /dev/vdb1",
              "zfs create -o mountpoint=legacy testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/old-data",
              "echo 'old data from previous usage' > /mnt/root/old-data/file.txt",
              "sync",
              "umount /mnt/root",
          )

      with subtest("Verify no @blank exists before reboot"):
          machine.fail("zfs list -t snapshot testpool/root@blank")

      with subtest("Reboot to trigger initrd bootstrap"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify impermanence service ran bootstrap"):
          print(machine.succeed("journalctl -b | grep -i 'zfs\|testpool\|impermanence' | head -80 || true"))
          print(machine.succeed("zpool list || true"))
          print(machine.succeed("journalctl -b -u impermanence-wipe-zfs.service 2>&1 || true"))
          machine.succeed("journalctl -b -u impermanence-wipe-zfs.service | grep -q 'bootstrapping'")

      with subtest("Verify @blank was created"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")

      with subtest("Verify @last backup was created"):
          machine.succeed("zfs list -t snapshot testpool/root@last")

      with subtest("Verify root dataset is now empty"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/old-data/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Verify @last snapshot has backup data"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery -o ro",
          )
          machine.succeed("test -f /mnt/recovery/old-data/file.txt")
          machine.succeed("grep -q 'old data from previous usage' /mnt/recovery/old-data/file.txt")
          machine.succeed("umount /mnt/recovery")

      # Test transition to normal path with another reboot
      with subtest("Add new data after bootstrap"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/new-session",
              "echo 'new session data' > /mnt/root/new-session/file.txt",
              "sync",
              "umount /mnt/root",
          )

      with subtest("Second reboot (normal path)"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify normal rollback happened"):
          machine.succeed("journalctl -b -u impermanence-wipe-zfs.service | grep -q 'Rolling back'")

      with subtest("Verify new session data was wiped"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/new-session/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Verify @last still has original backup (not replaced)"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery -o ro",
          )
          machine.succeed("test -f /mnt/recovery/old-data/file.txt")
          machine.fail("test -f /mnt/recovery/new-session/file.txt")
          machine.succeed("umount /mnt/recovery")
    '';
  };
}
