# Impermanence module tests
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
      };
      boot = {
        loader.systemd-boot.enable = true;
        loader.timeout = 0;
        loader.efi.canTouchEfiVariables = true;
        supportedFilesystems = [ "zfs" ];
        zfs.devNodes = "/dev/disk/by-uuid";
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
      fileSystems."/persist" = {
        device = "testpool/persist";
        fsType = "zfs";
        neededForBoot = true;
      };
    };

  setupPoolScript = ''
    machine.succeed(
        "parted --script /dev/vdb mklabel gpt",
        "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
        "udevadm settle",
        "zpool create -f testpool /dev/vdb1",
        "zfs create -o mountpoint=legacy testpool/root",
        "zfs create -o mountpoint=/persist testpool/persist",
    )
  '';
in
{
  # Test normal path: @blank exists, fast rollback
  wipeOnBoot = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machine;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Create ZFS pool and datasets"):
          ${setupPoolScript}

      with subtest("Setup: create @blank and add ephemeral data"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.succeed("zfs snapshot testpool/root@blank")
          machine.succeed(
              "mkdir -p /mnt/root/ephemeral",
              "echo 'ephemeral data' > /mnt/root/ephemeral/file.txt",
              "umount /mnt/root",
          )
          machine.succeed(
              "mkdir -p /persist/important",
              "echo 'persistent data' > /persist/important/file.txt",
          )

      with subtest("Execute rollback"):
          machine.succeed("zfs rollback -r testpool/root@blank")

      with subtest("Verify only @blank snapshot exists"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")
          output = machine.succeed("zfs list -t snapshot -H -o name testpool/root | wc -l")
          assert output.strip() == "1", f"Expected 1 snapshot, got {output.strip()}"

      with subtest("Verify ephemeral data wiped"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/ephemeral/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Verify persistent data survived"):
          machine.succeed("test -f /persist/important/file.txt")

      with subtest("Verify no @last snapshot exists (normal path)"):
          machine.fail("zfs list -t snapshot testpool/root@last")
    '';
  };

  # Test bootstrap path: no @blank, backup to @last + wipe + create @blank
  wipeOnBootBootstrap = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot-bootstrap";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machine;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("Create ZFS pool with existing data"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1MiB 100%",
              "udevadm settle",
              "zpool create -f testpool /dev/vdb1",
              "zfs create -o mountpoint=legacy testpool/root",
          )
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/old-data",
              "echo 'old data from previous usage' > /mnt/root/old-data/file.txt",
              "umount /mnt/root",
          )

      with subtest("Verify no @blank exists"):
          machine.fail("zfs list -t snapshot testpool/root@blank")

      with subtest("Execute bootstrap"):
          machine.succeed(
              # Backup current state as @last snapshot
              "zfs snapshot testpool/root@last",
              # Wipe dataset contents
              "mkdir -p /mnt/wipe",
              "mount -t zfs testpool/root /mnt/wipe",
              "rm -rf /mnt/wipe/* /mnt/wipe/.[!.]* /mnt/wipe/..?* 2>/dev/null || true",
              "umount /mnt/wipe",
              # Create @blank
              "zfs snapshot testpool/root@blank",
          )

      with subtest("Verify @blank and @last snapshots exist"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")
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

      # Test transition to normal path
      with subtest("Add new data after bootstrap"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/new-session",
              "echo 'new session data' > /mnt/root/new-session/file.txt",
              "umount /mnt/root",
          )

      with subtest("Execute normal rollback (second boot)"):
          machine.succeed("zfs rollback -r testpool/root@blank")

      with subtest("Verify new session data wiped"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/new-session/file.txt")
          machine.succeed("umount /mnt/root")

      with subtest("Verify @last still has original backup"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery -o ro",
          )
          machine.succeed("test -f /mnt/recovery/old-data/file.txt")
          machine.succeed("umount /mnt/recovery")

      # Test re-bootstrap replaces @last
      with subtest("Simulate re-bootstrap by destroying @blank"):
          machine.succeed("zfs destroy testpool/root@blank")
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/reinstall-data",
              "echo 'data from reinstall' > /mnt/root/reinstall-data/file.txt",
              "umount /mnt/root",
          )

      with subtest("Execute re-bootstrap (replaces @last)"):
          machine.succeed(
              "zfs destroy testpool/root@last",
              "zfs snapshot testpool/root@last",
              "mkdir -p /mnt/wipe",
              "mount -t zfs testpool/root /mnt/wipe",
              "rm -rf /mnt/wipe/* /mnt/wipe/.[!.]* /mnt/wipe/..?* 2>/dev/null || true",
              "umount /mnt/wipe",
              "zfs snapshot testpool/root@blank",
          )

      with subtest("Verify @last now has reinstall data"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery -o ro",
          )
          machine.succeed("test -f /mnt/recovery/reinstall-data/file.txt")
          # Old backup data should be gone
          machine.fail("test -f /mnt/recovery/old-data/file.txt")
          machine.succeed("umount /mnt/recovery")
    '';
  };
}
