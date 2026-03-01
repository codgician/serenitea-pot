# Impermanence module tests
{
  lib,
  pkgs,
  ...
}:

let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
in
{
  wipeOnBoot = nixos-lib.runTest {
    name = "impermanence-wipe-on-boot";
    hostPkgs = pkgs;

    defaults = {
      imports = lib.codgician.mkNixosModules pkgs.stdenv.hostPlatform.system { };
      nixpkgs.overlays = pkgs.overlays;
    };

    nodes.machine = ./machine.nix;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Create ZFS pool with root (ephemeral) and persist datasets
      with subtest("Create ZFS pool and datasets"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1M -1s",
              "zpool create -f testpool /dev/vdb1",
              "zfs create -o mountpoint=legacy testpool/root",
              "zfs create -o mountpoint=/persist testpool/persist",
          )

      # Create data in root dataset (should be wiped) and persist (should survive)
      with subtest("Create test data"):
          # Mount root dataset temporarily to add data
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/ephemeral",
              "echo 'ephemeral data' > /mnt/root/ephemeral/file.txt",
              "umount /mnt/root",
          )
          # Add data to persist (should NOT be wiped)
          machine.succeed(
              "mkdir -p /persist/important",
              "echo 'persistent data' > /persist/important/file.txt",
          )
          machine.succeed("test -f /persist/important/file.txt")

      # Export pool for clean reimport on boot
      with subtest("Export pool for reboot"):
          machine.succeed(
              "umount /persist || true",
              "zpool export testpool",
          )

      # Reboot to trigger bootstrap (no @blank snapshot exists yet)
      with subtest("Reboot to trigger bootstrap"):
          machine.crash()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      # Verify bootstrap occurred on root dataset only
      with subtest("Verify bootstrap created snapshots on root dataset"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")
          machine.succeed("zfs list -t snapshot testpool/root@last")
          # Persist should NOT have these snapshots (it's not being wiped)
          machine.fail("zfs list -t snapshot testpool/persist@blank")

      # Verify root was wiped but persist data survived
      with subtest("Verify root wiped, persist untouched"):
          # Mount root to check it's empty
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/ephemeral/file.txt")
          machine.succeed("umount /mnt/root")
          # Persist data should still exist
          machine.succeed("test -f /persist/important/file.txt")
          machine.succeed("grep -q 'persistent data' /persist/important/file.txt")

      # Verify old root data is recoverable from @last snapshot
      with subtest("Verify old root data recoverable from @last snapshot"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery",
          )
          machine.succeed("test -f /mnt/recovery/ephemeral/file.txt")
          machine.succeed("grep -q 'ephemeral data' /mnt/recovery/ephemeral/file.txt")
          machine.succeed("umount /mnt/recovery")

      # Create new data in root and reboot to test normal rollback
      with subtest("Create new root data for rollback test"):
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
              "mkdir -p /mnt/root/session",
              "echo 'session data' > /mnt/root/session/data.txt",
              "umount /mnt/root",
          )

      # Reboot to trigger normal rollback
      with subtest("Reboot to trigger normal rollback"):
          machine.succeed("zpool export testpool")
          machine.crash()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      # Verify rollback occurred
      with subtest("Verify rollback wiped new root data"):
          machine.succeed("zfs list -t snapshot testpool/root@blank")
          machine.succeed("zfs list -t snapshot testpool/root@last")
          # New session data should be gone after rollback
          machine.succeed(
              "mkdir -p /mnt/root",
              "mount -t zfs testpool/root /mnt/root",
          )
          machine.fail("test -f /mnt/root/session/data.txt")
          machine.succeed("umount /mnt/root")

      # Verify @last now contains the session data (from before rollback)
      with subtest("Verify @last contains previous session data"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/root@last /mnt/recovery",
          )
          machine.succeed("test -f /mnt/recovery/session/data.txt")
          machine.succeed("grep -q 'session data' /mnt/recovery/session/data.txt")
          machine.succeed("umount /mnt/recovery")

      # Persist data should still be intact throughout
      with subtest("Verify persist data survived all reboots"):
          machine.succeed("test -f /persist/important/file.txt")
          machine.succeed("grep -q 'persistent data' /persist/important/file.txt")

      with subtest("Final state verification"):
          print(machine.succeed("zfs list -t snapshot"))
    '';
  };
}
