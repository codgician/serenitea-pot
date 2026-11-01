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
  fixtures = ../secrets/fixtures;
  passphrase = "correct horse battery";

  # An installed host whose disks the test formats at runtime: an ESP and an
  # encrypted ZFS root with impermanence, plus a LUKS data disk keyed from
  # /persist. Its partition labels and pool name follow disko's naming, which
  # the "receiving machine" disk in the test reuses.
  fixtureHost = lib.codgician.mkNixosSystem {
    hostName = "fixture";
    inherit system;
    modules = [
      {
        networking.hostId = "deadbeef";
        boot.loader.grub.enable = false;
        fileSystems = {
          "/" = {
            device = "zroot/root";
            fsType = "zfs";
            options = [ "zfsutil" ];
          };
          "/boot" = {
            device = "/dev/disk/by-partlabel/disk-main-esp";
            fsType = "vfat";
            options = [ "umask=0077" ];
          };
          "/nix" = {
            device = "zroot/nix";
            fsType = "zfs";
            options = [ "zfsutil" ];
          };
          "/persist" = {
            device = "zroot/persist";
            fsType = "zfs";
            options = [ "zfsutil" ];
            neededForBoot = true;
          };
          "/data" = {
            device = "/dev/mapper/crypted-data";
            fsType = "ext4";
          };
        };
        boot.initrd.luks.devices.crypted-data = {
          device = "/dev/disk/by-partlabel/disk-data-luks";
          keyFile = "/sysroot/persist/keys/data.key";
        };
        codgician.system.impermanence.enable = true;
        system.stateVersion = "26.05";
      }
    ];
  };

  hosts.fixture = import ../../packages/installer-iso/rescue/host.nix { inherit lib; } {
    host = fixtureHost;
    hostKeys = [ (lib.fileContents (fixtures + "/ssh_host_ed25519_key.pub")) ];
  };
in
{
  rescue = nixos-lib.runTest {
    name = "rescue";
    hostPkgs = pkgs;
    defaults = {
      imports = lib.codgician.mkNixosModules system { };
      nixpkgs.overlays = pkgs.overlays;
      _module.args = {
        inherit inputs outputs system;
      };
    };

    nodes.machine = {
      imports = [
        (import ../../packages/installer-iso/rescue {
          inherit hosts;
          revision = "test";
        })
      ];
      nixpkgs.config.allowUnfree = true;
      virtualisation = {
        memorySize = 2048;
        # vdb: fixture ESP + root pool, vdc: fixture data,
        # vdd: the receiving machine's own disk with the same names.
        emptyDiskImages = [
          1024
          256
          1024
        ];
      };
      boot.supportedFilesystems = [ "zfs" ];
      networking.hostId = "8425e349";
      environment.systemPackages = with pkgs; [
        cryptsetup
        dosfstools
      ];
      sops.secrets.test-api-key = {
        sopsFile = fixtures + "/values/test-api-key";
        format = "binary";
      };
    };

    testScript = ''
      passphrase = "${passphrase}"

      def unlock(answers, flags=""):
          return f"printf '%s\\n' {answers} | rescue unlock {flags} fixture 2>&1"

      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("nothing is decrypted at boot"):
          machine.fail("systemctl is-active sops-install-secrets.service")
          machine.fail("test -e /run/secrets")
          machine.succeed("rescue status | grep -E '^State +locked'")

      with subtest("prepare the receiving machine's disk"):
          machine.succeed(
              "printf 'label: gpt\\nsize=64M, name=disk-main-esp\\nsize=512M, name=disk-main-zroot\\n' | sfdisk -q /dev/vdd",
              "udevadm settle",
              "mkfs.vfat /dev/vdd1",
              "mkdir -p /tmp/esp && mount /dev/vdd1 /tmp/esp && echo decoy > /tmp/esp/marker && umount /tmp/esp",
              "zpool create -O mountpoint=none zroot /dev/vdd2",
              "zpool export zroot",
              "udevadm settle",
          )

      with subtest("install the fixture host"):
          machine.succeed(
              "printf 'label: gpt\\nsize=64M, name=disk-main-esp\\nname=disk-main-zroot\\n' | sfdisk -q /dev/vdb",
              "printf 'label: gpt\\nname=disk-data-luks\\n' | sfdisk -q /dev/vdc",
              "udevadm settle",
              "mkfs.vfat /dev/vdb1",
              "mount /dev/vdb1 /tmp/esp && echo fixture > /tmp/esp/marker && umount /tmp/esp",
              f"echo '{passphrase}' | zpool create -R /tmp/host -O mountpoint=none"
              " -O encryption=on -O keyformat=passphrase -O keylocation=prompt zroot /dev/vdb2",
              "zfs create -o mountpoint=/ zroot/root",
              "zfs create -o mountpoint=/nix zroot/nix",
              "zfs create -o mountpoint=/persist zroot/persist",
              "mkdir -p /tmp/host/persist/etc/ssh /tmp/host/persist/var/log /tmp/host/persist/keys",
              "install -m 600 ${
                fixtures + "/ssh_host_ed25519_key"
              } /tmp/host/persist/etc/ssh/ssh_host_ed25519_key",
              "echo persisted > /tmp/host/persist/var/log/marker",
              "head -c 64 /dev/urandom > /tmp/host/persist/keys/data.key",
              "cryptsetup luksFormat --batch-mode --pbkdf pbkdf2 --key-file /tmp/host/persist/keys/data.key /dev/vdc1",
              "cryptsetup open --key-file /tmp/host/persist/keys/data.key /dev/vdc1 setup-data",
              "mkfs.ext4 -q /dev/mapper/setup-data",
              "mkdir -p /tmp/data && mount /dev/mapper/setup-data /tmp/data",
              "echo data > /tmp/data/file && umount /tmp/data",
              "cryptsetup close setup-data",
          )
          guid = machine.succeed("zpool get -H -o value guid zroot").strip()
          machine.succeed("zpool export zroot", "udevadm settle")
          hostid = machine.succeed("cat /sys/module/spl/parameters/spl_hostid").strip()

      with subtest("same-named pools without a matching label ask which one to use"):
          out = machine.succeed(unlock(f"1 '{passphrase}'"))
          assert "Several importable pools are named zroot" in out, out
          imported = machine.succeed("zpool get -H -o value guid zroot").strip()
          assert imported == guid, f"imported the wrong pool: {imported}"

      with subtest("read-only unlock mounts the host and decrypts with its key"):
          adopted = machine.succeed("cat /sys/module/spl/parameters/spl_hostid").strip()
          assert adopted == str(0xdeadbeef), f"host id not adopted: {adopted}"
          machine.succeed("grep -qx fixture /mnt/boot/marker")
          machine.succeed("findmnt -no OPTIONS /mnt/persist | grep -qw ro")
          machine.fail("touch /mnt/persist/written")
          machine.succeed("grep -qx persisted /mnt/var/log/marker")
          machine.succeed("grep -qx data /mnt/data/file")
          machine.fail("touch /mnt/data/written")
          secret = machine.succeed("cat /run/secrets/test-api-key").strip()
          assert secret == "sk-test-12345", f"unexpected secret: {secret!r}"
          machine.succeed("rescue status | grep -E '^Secrets +unlocked'")

      with subtest("read-write unlock relocks and prepares the tree for nixos-enter"):
          machine.succeed(unlock(f"1 '{passphrase}'", "--rw"))
          machine.succeed(
              "test -e /mnt/etc/NIXOS",
              "touch /mnt/persist/written",
              "touch /mnt/data/written",
              "rescue status | grep -E '^Mode +read-write'",
          )
          # Plant another host's key for the mismatch checks below.
          machine.succeed(
              "ssh-keygen -q -t ed25519 -N ''' -f /tmp/other-host-key",
              "install -m 600 /tmp/other-host-key /mnt/persist/etc/ssh/ssh_host_ed25519_key",
          )

      with subtest("lock wipes secrets and releases the disks"):
          machine.succeed("rescue lock")
          machine.fail("test -e /run/secrets")
          machine.fail("mountpoint -q /mnt")
          machine.fail("zpool list zroot")
          machine.fail("test -e /dev/mapper/crypted-data")
          restored = machine.succeed("cat /sys/module/spl/parameters/spl_hostid").strip()
          assert restored == hostid, f"host id not restored: {restored}"
          machine.succeed("rescue status | grep -E '^State +locked'")

      with subtest("a pool last imported as the host is picked without asking"):
          out = machine.fail(unlock(f"'{passphrase}'", "--rw"))
          assert "Several importable pools" not in out, out

      with subtest("another host's key refuses read-write and rolls back"):
          assert "refusing read-write" in out, out
          machine.fail("zpool list zroot")
          machine.fail("mountpoint -q /mnt")
          machine.succeed("rescue status | grep -E '^State +locked'")

      with subtest("another host's key still mounts read-only, without secrets"):
          machine.succeed(unlock(f"'{passphrase}'"))
          machine.succeed("rescue status | grep -E '^Secrets +locked: host key does not match'")
          machine.fail("test -e /run/secrets")
          machine.succeed("rescue lock")

      with subtest("a wrong passphrase rolls everything back"):
          machine.fail(unlock("'wrong pass' 'wrong pass' 'wrong pass'"))
          machine.fail("zpool list zroot")
          machine.fail("mountpoint -q /mnt")
          machine.succeed("rescue status | grep -E '^State +locked'")
    '';
  };
}
