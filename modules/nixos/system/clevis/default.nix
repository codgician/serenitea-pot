{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.codgician.system.clevis;

  # Parse JWE header for pattern matching
  getJweHeader =
    secretFile:
    let
      jweContent = builtins.readFile secretFile;
      parts = builtins.split "\\." jweContent;
    in
    builtins.elemAt parts 0;

  # Detect pin type from JWE header using base64-encoded pattern matching
  # JWE header contains '{"...","clevis":{"pin":"<type>",...}' which encodes to
  # recognizable base64 patterns regardless of byte alignment
  detectPinType =
    secretFile:
    let
      header = getJweHeader secretFile;
      # Base64-encoded patterns for '"pin":"<type>"' at common byte alignments
      hasTpm2 = builtins.match ".*cGluIjoidHBtMi.*" header != null;
      hasTang = builtins.match ".*cGluIjoidGFuZy.*" header != null;
    in
    if hasTpm2 then
      "tpm2"
    else if hasTang then
      "tang"
    else
      "tpm2"; # Fallback

  # Detect PCR bank from JWE header
  # Matches 'cr_bank":"shaXXX' pattern (at byte offset 1 in base64)
  # This is more robust than matching just 'shaXXX' which could match other fields
  detectPcrBank =
    secretFile:
    let
      header = getJweHeader secretFile;
      # Base64 patterns for 'cr_bank":"shaXXX' (pcr_bank field at offset 1)
      # Y3JfYmFuayI6InNoYTI1Ni = cr_bank":"sha256
      # Y3JfYmFuayI6InNoYTM4NC = cr_bank":"sha384
      # Y3JfYmFuayI6InNoYTUxMi = cr_bank":"sha512
      hasSha256 = builtins.match ".*Y3JfYmFuayI6InNoYTI1Ni.*" header != null;
      hasSha384 = builtins.match ".*Y3JfYmFuayI6InNoYTM4NC.*" header != null;
      hasSha512 = builtins.match ".*Y3JfYmFuayI6InNoYTUxMi.*" header != null;
    in
    if hasSha256 then
      "sha256"
    else if hasSha384 then
      "sha384"
    else if hasSha512 then
      "sha512"
    else
      throw "codgician.system.clevis: Could not detect PCR bank from JWE file '${toString secretFile}'. Ensure the JWE contains a valid tpm2 pin with pcr_bank field.";

  # Device submodule options
  deviceOptions =
    { ... }:
    {
      options = {
        secretFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to the Clevis JWE file used to decrypt the device.
            Generate with: `nix run .#mkjwe -- tpm` or `nix run .#mkjwe -- tang --url <url>`
          '';
        };
      };
    };

  # Check if any device uses Tang (needs network in initrd)
  usesTang = lib.any (dev: detectPinType dev.secretFile == "tang") (lib.attrValues cfg.devices);

  # Get TPM2 devices for PCR extension
  tpm2Devices = lib.filterAttrs (_: dev: detectPinType dev.secretFile == "tpm2") cfg.devices;

  # Get unique PCR banks used across all TPM2 devices
  tpm2PcrBanks = lib.unique (lib.mapAttrsToList (_: dev: detectPcrBank dev.secretFile) tpm2Devices);

  # Supported filesystem types for automatic service ordering
  supportedFs = [
    "zfs"
    "luks"
    "bcachefs"
  ];

  # Detect filesystem type for each device to determine correct service ordering
  # Returns: "zfs", "luks", "bcachefs", or null if unknown
  deviceFsType =
    name:
    if lib.hasAttr name config.boot.initrd.luks.devices then
      "luks"
    else if
      lib.any (
        fs: fs.fsType == "zfs" && (fs.device == name || lib.hasPrefix "${name}/" fs.device)
      ) config.system.build.fileSystems
    then
      "zfs"
    else if
      lib.any (fs: fs.fsType == "bcachefs" && fs.device == name) config.system.build.fileSystems
    then
      "bcachefs"
    else
      null;

  # Get systemd service to wait for based on filesystem type
  # - ZFS: clevis runs inline in zfs-import-<pool>.service
  # - LUKS: cryptsetup-clevis-<device>.service -> systemd-cryptsetup@<device>.service
  # - bcachefs: bcachefs-mount.target (device unlocked before mount)
  deviceWaitService =
    name:
    let
      fsType = deviceFsType name;
    in
    if fsType == "zfs" then
      "zfs-import-${name}.service"
    else if fsType == "luks" then
      "systemd-cryptsetup@${utils.escapeSystemdPath name}.service"
    else if fsType == "bcachefs" then
      "bcachefs-mount.target"
    else
      null;

  # All wait services for configured devices (filter out nulls from unknown types)
  deviceWaitServices = lib.filter (s: s != null) (
    lib.map deviceWaitService (lib.attrNames cfg.devices)
  );

  # Zero values for each PCR bank (used for extension)
  # Hash output sizes: sha1=20, sha256=32, sha384=48, sha512=64 bytes
  # Each byte = 2 hex chars, so we generate strings of 2*N zeros
  mkZeros = n: lib.concatStrings (lib.genList (_: "00") n);
  bankZeros = {
    sha1 = mkZeros 20;
    sha256 = mkZeros 32;
    sha384 = mkZeros 48;
    sha512 = mkZeros 64;
  };

  # Script to extend PCR 15 in all detected PCR banks
  # PCR banks are detected at Nix eval time from JWE headers
  pcrExtendScript = pkgs.writeShellScript "clevis-pcr15-extend" ''
    set -euo pipefail

    ${lib.concatMapStrings (bank: ''
      echo "clevis-pcr15-extend: Extending PCR 15 in ${bank} bank"
      ${pkgs.tpm2-tools}/bin/tpm2_pcrextend "15:${bank}=${bankZeros.${bank}}"
    '') tpm2PcrBanks}
  '';
in
{
  options.codgician.system.clevis = {
    enable = lib.mkEnableOption "Clevis-based disk unlock in initrd";

    devices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule deviceOptions);
      default = { };
      description = ''
        Devices to unlock with Clevis during boot.
        The attribute name should match the ZFS pool, LUKS device, or bcachefs filesystem name.
      '';
      example = lib.literalExpression ''
        {
          zroot.secretFile = ./zroot.jwe;
        }
      '';
    };

    package = lib.mkPackageOption pkgs "clevis" { };

    tpm2 = {
      pcrExtend = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to extend PCR 15 after successful clevis unlock.
            This mitigates the filesystem confusion attack by ensuring
            the TPM secret can only be unsealed once per boot.

            PCR bank is automatically detected from each device's JWE header.

            When enabled, your JWE must include PCR 15 in the policy.
            Generate with: `nix run .#mkjwe -- tpm --pcr-ids 1,2,7,12,14,15`
          '';
        };

        afterServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Additional systemd services to wait for before extending PCR 15.
            By default, waits for ZFS import or LUKS cryptsetup services
            based on device type detection.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Assert all devices have a known filesystem type (similar to nixpkgs clevis module)
      {
        assertions = lib.mapAttrsToList (name: _: {
          assertion =
            let
              fsType = deviceFsType name;
            in
            fsType != null && lib.elem fsType supportedFs;
          message = ''
            codgician.system.clevis: Device '${name}' has no matching filesystem or LUKS device.
            Supported types: ${lib.concatStringsSep ", " supportedFs}.
            Ensure the device name matches a ZFS pool, LUKS device, or bcachefs filesystem.
          '';
        }) cfg.devices;
      }

      # Pass through to upstream clevis module
      {
        boot.initrd.clevis = {
          enable = true;
          package = cfg.package;
          useTang = usesTang;
          devices = lib.mapAttrs (_: dev: { inherit (dev) secretFile; }) cfg.devices;
        };
      }

      # PCR 15 extension mitigation for TPM2
      (lib.mkIf (cfg.tpm2.pcrExtend.enable && tpm2Devices != { }) {
        boot.initrd.systemd = {
          storePaths = [
            "${pkgs.tpm2-tools}/bin/tpm2_pcrextend"
            pcrExtendScript
          ];

          services.clevis-pcr15-extend = {
            description = "Extend PCR 15 after Clevis unlock (anti-replay mitigation)";

            # Wait for all detected device services + any custom services
            after = deviceWaitServices ++ cfg.tpm2.pcrExtend.afterServices;

            # Must complete before mounting root filesystem
            before = [ "initrd-root-fs.target" ];
            wantedBy = [ "initrd-root-fs.target" ];

            # Only run if TPM is available
            unitConfig.ConditionPathExists = "/dev/tpm0";

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pcrExtendScript;
            };
          };
        };
      })
    ]
  );
}
