# ZFS crypto fingerprint: hash(GUID || MAC) from encryption metadata
#
# Security: MAC is AES-GCM auth tag (unforgeable without key),
# GUID is unique per encryption root. Together they identify legitimate volumes.
#
# Performance: Targeted zdb queries (~1-2s) vs full scan (~15s)
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
    guid=$(echo "$crypto_out" | ${grep} -oP -m1 'DSL_CRYPTO_GUID = \K-?\d+') || true
    mac=$(echo "$crypto_out" | ${grep} -oP -m1 'DSL_CRYPTO_MAC = \K[0-9a-fA-F]+') || true

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
