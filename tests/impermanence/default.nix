# Impermanence module integration tests
#
# These tests verify the impermanence wipe-on-boot behavior:
#
# wipeOnBoot: Normal path - rollback to @blank snapshot in initrd
#   1. Create ZFS pool with @blank snapshot
#   2. Add ephemeral data
#   3. Reboot and verify data is wiped (rolled back to @blank)
#
# wipeOnBootBootstrap: Bootstrap path - create @blank from empty state
#   1. Create ZFS pool with existing data (no @blank)
#   2. Boot - initrd creates @last backup, wipes, creates @blank, reboots
#   3. After auto-reboot, verify normal rollback works
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

  # Base machine config with impermanence enabled (normal path)
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
    nodes.machine = machineBase;

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
              # Use native ZFS mountpoints like production (not legacy)
              "zfs create -o mountpoint=/testroot testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )

      with subtest("Create @blank snapshot"):
          # Dataset is already mounted at /testroot by ZFS
          machine.succeed("zfs snapshot testpool/root@blank")

      with subtest("Add ephemeral data after @blank"):
          machine.succeed(
              "mkdir -p /testroot/ephemeral",
              "echo 'ephemeral data' > /testroot/ephemeral/file.txt",
              "sync",
          )

      with subtest("Add persistent data"):
          machine.succeed(
              "mkdir -p /persist/important",
              "echo 'persistent data' > /persist/important/file.txt",
              "sync",
          )

      with subtest("Verify ephemeral data exists before reboot"):
          machine.succeed("test -f /testroot/ephemeral/file.txt")

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
          # After rollback, dataset should be mounted at /testroot
          machine.succeed("zfs mount testpool/root || true")  # Mount if not already
          machine.fail("test -f /testroot/ephemeral/file.txt")

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

  # Integration test: Bootstrap path (no @blank exists)
  # Tests that initrd creates @blank and reboots automatically
  wipeOnBootBootstrap = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot-bootstrap";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machineBase;

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
              "zfs create -o mountpoint=/testroot testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )
          # Add pre-existing data (simulating existing system)
          machine.succeed(
              "mkdir -p /testroot/old-data",
              "echo 'old data from before impermanence' > /testroot/old-data/file.txt",
              "mkdir -p /persist/important",
              "echo 'persistent data' > /persist/important/file.txt",
              "sync",
          )

      with subtest("Verify no @blank exists"):
          machine.fail("zfs list -t snapshot testpool/root@blank")

      with subtest("Reboot to trigger bootstrap (creates @blank and auto-reboots)"):
          machine.shutdown()
          machine.start()
          # The initrd will bootstrap and trigger a reboot
          # We need to wait longer since there may be an auto-reboot
          machine.wait_for_unit("multi-user.target", timeout=120)

      with subtest("Debug: check logs and snapshots"):
          print(machine.succeed("journalctl --list-boots 2>&1 || true"))
          print(machine.succeed("journalctl -b -u impermanence-wipe-zfs.service 2>&1 || true"))
          print(machine.succeed("zfs list -t snapshot 2>&1 || true"))

      with subtest("Verify @blank was created"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")

      with subtest("Verify @last backup was created"):
          machine.succeed("zfs list -t snapshot testpool/root@last")

      with subtest("Verify old data was wiped from root"):
          machine.succeed("zfs mount testpool/root || true")
          machine.fail("test -f /testroot/old-data/file.txt")

      with subtest("Verify persistent data survived"):
          machine.succeed("test -f /persist/important/file.txt")

      with subtest("Verify @last snapshot has backup of old data"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery -o ro",
          )
          machine.succeed("test -f /mnt/recovery/old-data/file.txt")
          machine.succeed("grep -q 'old data from before impermanence' /mnt/recovery/old-data/file.txt")
          machine.succeed("umount /mnt/recovery")

      # Test that subsequent boots use normal rollback path
      with subtest("Add new ephemeral data"):
          machine.succeed(
              "mkdir -p /testroot/new-session",
              "echo 'new session data' > /testroot/new-session/file.txt",
              "sync",
          )

      with subtest("Reboot to verify normal rollback"):
          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      with subtest("Verify normal rollback happened"):
          machine.succeed("journalctl -b -u impermanence-wipe-zfs.service | grep -q 'Rolling back'")

      with subtest("Verify new session data was wiped"):
          machine.succeed("zfs mount testpool/root || true")
          machine.fail("test -f /testroot/new-session/file.txt")
    '';
  };
}
