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
      imports = lib.codgician.mkNixosModules pkgs.system { };
      nixpkgs.overlays = pkgs.overlays;
    };

    nodes.machine = ./machine.nix;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Create ZFS pool and persist dataset on the empty disk
      with subtest("Create ZFS pool and persist dataset"):
          machine.succeed(
              "parted --script /dev/vdb mklabel gpt",
              "parted --script /dev/vdb -- mkpart primary 1M -1s",
              "zpool create -f testpool /dev/vdb1",
              "zfs create -o mountpoint=/persist testpool/persist",
          )

      # Create dirty data to test bootstrap scenario
      with subtest("Create dirty data before bootstrap"):
          machine.succeed(
              "mkdir -p /persist/testdir",
              "echo 'dirty data' > /persist/testdir/testfile.txt",
              "echo 'secret' > /persist/.hidden_file",
          )
          machine.succeed("test -f /persist/testdir/testfile.txt")
          machine.succeed("test -f /persist/.hidden_file")
          machine.succeed("grep -q 'dirty data' /persist/testdir/testfile.txt")

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

      # Verify bootstrap occurred
      with subtest("Verify bootstrap created snapshots and wiped data"):
          machine.succeed("zfs list -t snapshot testpool/persist@blank")
          machine.succeed("zfs list -t snapshot testpool/persist@last")
          machine.fail("test -f /persist/testdir/testfile.txt")
          machine.fail("test -f /persist/.hidden_file")

      # Verify old data is recoverable from @last snapshot
      with subtest("Verify old data recoverable from @last snapshot"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/persist@last /mnt/recovery",
          )
          machine.succeed("test -f /mnt/recovery/testdir/testfile.txt")
          machine.succeed("grep -q 'dirty data' /mnt/recovery/testdir/testfile.txt")
          machine.succeed("test -f /mnt/recovery/.hidden_file")
          machine.succeed("umount /mnt/recovery")

      # Create new data and reboot to test normal rollback path
      with subtest("Create new data for rollback test"):
          machine.succeed(
              "mkdir -p /persist/newdir",
              "echo 'new session data' > /persist/newdir/session.txt",
          )
          machine.succeed("test -f /persist/newdir/session.txt")

      # Reboot to trigger normal rollback (not bootstrap)
      with subtest("Reboot to trigger normal rollback"):
          machine.crash()
          machine.start()
          machine.wait_for_unit("multi-user.target")

      # Verify normal rollback occurred
      with subtest("Verify rollback wiped new data"):
          machine.succeed("zfs list -t snapshot testpool/persist@blank")
          machine.succeed("zfs list -t snapshot testpool/persist@last")
          machine.fail("test -f /persist/newdir/session.txt")

      # Verify the new @last has the new session data
      with subtest("Verify @last contains previous session data"):
          machine.succeed(
              "mkdir -p /mnt/recovery",
              "mount -t zfs testpool/persist@last /mnt/recovery",
          )
          machine.succeed("test -f /mnt/recovery/newdir/session.txt")
          machine.succeed("grep -q 'new session data' /mnt/recovery/newdir/session.txt")
          machine.succeed("umount /mnt/recovery")

      with subtest("Final state verification"):
          print(machine.succeed("zfs list -t snapshot"))
    '';
  };
}
