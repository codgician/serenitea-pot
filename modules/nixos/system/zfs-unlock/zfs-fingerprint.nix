# Shared ZFS crypto fingerprint computation
#
# Used by both:
#   - zfs-unlock service (initrd) for PCR 15 extension
#   - mkzfscreds tool for expected PCR 15 computation
#
# Fingerprint = sha256(DSL_CRYPTO_GUID || DSL_CRYPTO_MAC)
#
# Security rationale:
#   - DSL_CRYPTO_MAC: AES-GCM auth tag, cannot be forged without passphrase
#   - DSL_CRYPTO_GUID: Unique per encryption root, included as AAD in MAC
#   - Together they uniquely identify a legitimate encrypted volume
#
# Performance: Uses targeted object queries instead of full pool scan
#   - Object 1 (MOS directory) -> root_dataset
#   - root_dataset -> crypto_key_obj
#   - crypto_key_obj -> GUID + MAC
#   Total: ~1-2 seconds vs ~15+ seconds for full -dddd scan
#
# Returns: { script, storePaths }
{
  pkgs,
  zfsPackage ? pkgs.zfs,
}:
let
  zdb = "${zfsPackage}/bin/zdb";
  grep = "${pkgs.gnugrep}/bin/grep";

  script = pkgs.writeShellScript "zfs-fingerprint" ''
    set -euo pipefail

    # Usage: zfs-fingerprint <dataset> [bank]
    # Outputs fingerprint to stdout, errors to stderr

    dataset="''${1:?Usage: zfs-fingerprint <dataset> [bank]}"
    bank="''${2:-sha256}"
    pool=''${dataset%%/*}

    # Step 1: Get root_dataset object ID from MOS directory (object 1)
    root_ds=$(${zdb} -ddddd "$pool" 1 2>/dev/null \
      | ${grep} -oP -m1 'root_dataset = \K\d+') || true

    if [[ -z "$root_ds" ]]; then
      echo "zfs-fingerprint: Cannot find root_dataset for $pool" >&2
      exit 1
    fi

    # Step 2: Get crypto_key_obj from root_dataset's DSL directory
    crypto_obj=$(${zdb} -ddddd "$pool" "$root_ds" 2>/dev/null \
      | ${grep} -oP -m1 'com\.datto:crypto_key_obj = \K\d+') || true

    if [[ -z "$crypto_obj" ]]; then
      echo "zfs-fingerprint: No crypto key for $pool (not encrypted?)" >&2
      exit 1
    fi

    # Step 3: Get GUID and MAC from crypto object
    crypto_out=$(${zdb} -ddddd "$pool" "$crypto_obj" 2>/dev/null)
    guid=$(echo "$crypto_out" | ${grep} -oP -m1 'DSL_CRYPTO_GUID = \K\d+') || true
    mac=$(echo "$crypto_out" | ${grep} -oP -m1 'DSL_CRYPTO_MAC = \K[0-9a-f]+') || true

    if [[ -z "$guid" || -z "$mac" ]]; then
      echo "zfs-fingerprint: Missing GUID or MAC for $pool" >&2
      exit 1
    fi

    # Compute fingerprint: hash(guid || mac)
    echo -n "''${guid}''${mac}" | "''${bank}sum" | cut -d' ' -f1
  '';
in
{
  inherit script;
  storePaths = [
    script
    zdb
    grep
  ];
}
