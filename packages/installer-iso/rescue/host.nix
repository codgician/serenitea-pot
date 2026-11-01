# Storage layout and identity of an installed host, extracted from its
# evaluated NixOS system so the `rescue` CLI can unlock it the way its own boot
# does.
{ lib }:
{ host, hostKeys }:
let
  inherit (host) config;
  luks = config.boot.initrd.luks.devices;
  supportedFsTypes = [
    "btrfs"
    "ext4"
    "tmpfs"
    "vfat"
    "xfs"
    "zfs"
  ];

  # LUKS devices unlocked by a key file stored on another file system of the
  # host (e.g. /sysroot/persist/keys/...) must mount after everything else.
  needsKeyFile =
    fs:
    lib.hasPrefix "/dev/mapper/" fs.device
    && (luks.${lib.removePrefix "/dev/mapper/" fs.device}.keyFile or null) != null;

  fileSystems = lib.pipe config.fileSystems [
    builtins.attrValues
    (builtins.filter (
      fs:
      builtins.elem fs.fsType supportedFsTypes
      && !builtins.elem "noauto" fs.options
      && !builtins.elem "bind" fs.options
    ))
    (map (fs: {
      inherit (fs) mountPoint fsType options;
      device = if fs.device == null then "none" else fs.device;
    }))
    (lib.sortOn (fs: fs.mountPoint))
  ];

  impermanence = config.codgician.system.impermanence;
in
{
  inherit hostKeys;
  hostId = config.networking.hostId;
  inherit (host.pkgs.stdenv.hostPlatform) system;
  secureBoot = config.boot.lanzaboote.enable;
  sshKey = lib.findFirst (_: true) null config.sops.age.sshKeyPaths;
  fileSystems =
    builtins.filter (fs: !needsKeyFile fs) fileSystems ++ builtins.filter needsKeyFile fileSystems;
  luks = lib.mapAttrs (_: device: { inherit (device) device keyFile; }) luks;
  pools = lib.unique (
    map (fs: builtins.head (lib.splitString "/" fs.device)) (
      builtins.filter (fs: fs.fsType == "zfs") fileSystems
    )
  );
  extraPools = config.boot.zfs.extraPools;
  persistPath = if impermanence.enable then impermanence.path else null;

  # Impermanence mounts these with systemd at boot, so they are absent from
  # fileSystems and from a plain chroot.
  binds =
    lib.concatMap
      (
        persistence:
        map (dir: {
          source = dir.persistentStoragePath + dir.dirPath;
          target = dir.dirPath;
        }) persistence.directories
      )
      (
        builtins.attrValues (
          lib.filterAttrs (_: persistence: persistence.enable) config.environment.persistence
        )
      );
}
