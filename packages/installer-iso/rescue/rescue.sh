# shellcheck shell=bash
# rescue: mount an installed host from the installer ISO and lock it again.
#
# RESCUE_MANIFEST holds the flake revision the ISO was built from and every
# host's storage layout and identity, extracted from its NixOS configuration
# (see host.nix).

root=/mnt
run_dir=/run/rescue
state_file=$run_dir/state.json
host_key_link=$run_dir/ssh_host_ed25519_key
lower=$run_dir/lower
upper=$run_dir/upper
spl_hostid=/sys/module/spl/parameters/spl_hostid
# Fixed by sops-nix (modules/sops/manifest-for.nix).
secrets_mount=/run/secrets.d
secrets_link=/run/secrets

host=
mode=
host_json=
hostid_orig=
identity=
pools=()
luks=()
# Physical disks already attributed to the host during this unlock.
chosen_disks=()

err() {
  printf 'rescue: %s\n' "$*" >&2
  exit 1
}
log() { printf '%s\n' "$*" >&2; }

host_names() { jq -r '.hosts | keys | join(" ")' "$RESCUE_MANIFEST"; }
host_entry() { jq -c --arg host "$1" '.hosts[$host] // empty' "$RESCUE_MANIFEST"; }
field() { jq -r "$1 // empty" <<<"$host_json"; }

usage() {
  cat >&2 <<EOF
Usage:
  rescue unlock [--rw] <host>   mount an installed host at $root (read-only unless --rw)
  rescue lock                   unmount, export pools, close LUKS, wipe decrypted secrets
  rescue status                 show what is mounted and unlocked

Hosts: $(host_names)
EOF
}

json_array() {
  if [ $# -eq 0 ]; then
    echo '[]'
  else
    printf '%s\n' "$@" | jq -R . | jq -sc .
  fi
}

# Every mutation is recorded before the next one, so `lock` can undo a
# partial unlock.
save_state() {
  mkdir -p "$run_dir"
  jq -n \
    --arg host "$host" \
    --arg mode "$mode" \
    --arg hostid "$hostid_orig" \
    --arg identity "$identity" \
    --argjson pools "$(json_array "${pools[@]}")" \
    --argjson luks "$(json_array "${luks[@]}")" \
    '{$host, $mode, $hostid, $identity, $pools, $luks}' >"$state_file.tmp"
  mv "$state_file.tmp" "$state_file"
}

load_state() {
  [ -f "$state_file" ] || return 1
  host=$(jq -r .host "$state_file")
  mode=$(jq -r .mode "$state_file")
  hostid_orig=$(jq -r .hostid "$state_file")
  identity=$(jq -r .identity "$state_file")
  mapfile -t pools < <(jq -r '.pools[]' "$state_file")
  mapfile -t luks < <(jq -r '.luks[]' "$state_file")
  host_json=$(host_entry "$host")
}

in_list() {
  local item=$1 entry
  shift
  for entry in "$@"; do
    if [ "$entry" = "$item" ]; then
      return 0
    fi
  done
  return 1
}

# Ask which candidate to use. Answers come from stdin like passphrases, so a
# whole unlock can be scripted. Sets `choice` to the zero-based index.
choose() {
  local question=$1 answer i
  shift
  log "$question"
  for ((i = 1; i <= $#; i++)); do
    log "  $i) ${!i}"
  done
  printf 'Choice [1-%d]: ' "$#" >&2
  read -r answer || err "no choice given"
  if ! [[ $answer =~ ^[0-9]+$ ]] || [ "$answer" -lt 1 ] || [ "$answer" -gt $# ]; then
    err "invalid choice: $answer"
  fi
  choice=$((answer - 1))
}

parent_disk() {
  local disk
  disk=$(lsblk -npdo PKNAME "$1")
  echo "${disk:-$1}"
}

remember_disk() {
  local disk
  disk=$(parent_disk "$1")
  in_list "$disk" "${chosen_disks[@]}" || chosen_disks+=("$disk")
}

# Partition labels repeat across hosts (disko names them disk-<disk>-<part>),
# so prefer partitions on disks already attributed to this host and ask when
# that does not settle it. Sets `resolved`, empty when no partition matches.
resolve_device() {
  local device=$1 label candidate disk choice
  local -a candidates preferred descriptions
  resolved=$device
  [[ $device == /dev/disk/by-partlabel/* ]] || return 0
  label=${device#/dev/disk/by-partlabel/}
  mapfile -t candidates < <(lsblk -rnpo PATH,PARTLABEL | awk -v label="$label" '$2 == label { print $1 }')
  if [ ${#candidates[@]} -eq 0 ]; then
    resolved=''
    return 0
  fi
  if [ ${#candidates[@]} -gt 1 ]; then
    preferred=()
    for candidate in "${candidates[@]}"; do
      if in_list "$(parent_disk "$candidate")" "${chosen_disks[@]}"; then
        preferred+=("$candidate")
      fi
    done
    [ ${#preferred[@]} -eq 0 ] || candidates=("${preferred[@]}")
  fi
  if [ ${#candidates[@]} -gt 1 ]; then
    descriptions=()
    for candidate in "${candidates[@]}"; do
      disk=$(parent_disk "$candidate")
      descriptions+=("$candidate on $disk ($(lsblk -dno MODEL,SERIAL,SIZE "$disk" | tr -s ' '))")
    done
    choose "Several partitions are labelled $label; which belongs to $host?" "${descriptions[@]}"
    candidates=("${candidates[choice]}")
  fi
  resolved=${candidates[0]}
  remember_disk "$resolved"
}

# "name guid hostid hostname device" for every ZFS member of a pool named $1.
pool_labels() {
  local device
  while read -r device; do
    zdb -l "$device" 2>/dev/null | awk -v device="$device" '
      $1 == "name:" && name == "" { name = $2 }
      $1 == "pool_guid:" && guid == "" { guid = $2 }
      $1 == "hostid:" && hostid == "" { hostid = $2 }
      $1 == "hostname:" && hostname == "" { hostname = $2 }
      END {
        gsub(/\047/, "", name)
        gsub(/\047/, "", hostname)
        if (guid != "") print name, guid, (hostid == "" ? "-" : hostid), (hostname == "" ? "-" : hostname), device
      }'
  done < <(lsblk -rnpo PATH,FSTYPE,LABEL | awk -v pool="$1" '$2 == "zfs_member" && $3 == pool { print $1 }')
}

# Pool names repeat across hosts (every root pool is zroot): pick the
# importable pool whose label names this host. Sets `selected_guid`.
select_pool() {
  local pool=$1 want='' host_id name guid hostid hostname device choice shown
  local -A members=()
  local -a guids=() matches=() descriptions=() devices
  host_id=$(field .hostId)
  [ -z "$host_id" ] || want=$((16#$host_id))
  while read -r name guid hostid hostname device; do
    if [ -z "${members[$guid]:-}" ]; then
      guids+=("$guid")
      shown=$hostid
      [[ ! $hostid =~ ^[0-9]+$ ]] || shown=$(printf '%08x' "$hostid")
      descriptions+=("$name $guid, last imported by $hostname (hostid $shown)")
      if { [ -n "$want" ] && [ "$hostid" = "$want" ]; } || [ "$hostname" = "$host" ]; then
        matches+=("$guid")
      fi
    fi
    members[$guid]+="$device "
  done < <(pool_labels "$pool")

  if [ ${#guids[@]} -eq 0 ]; then
    return 1
  elif [ ${#guids[@]} -eq 1 ]; then
    selected_guid=${guids[0]}
  elif [ ${#matches[@]} -eq 1 ]; then
    selected_guid=${matches[0]}
  else
    choose "Several importable pools are named $pool; which belongs to $host?" "${descriptions[@]}"
    selected_guid=${guids[choice]}
  fi
  read -ra devices <<<"${members[$selected_guid]}"
  for device in "${devices[@]}"; do
    remember_disk "$device"
  done
}

import_pool() {
  local pool=$1 selected_guid args=(-N -R "$root")
  if in_list "$pool" "${pools[@]}"; then
    return 0
  fi
  select_pool "$pool" || return 1
  [ "$mode" = rw ] || args+=(-o readonly=on)
  # By GUID: another importable pool may carry the same name.
  zpool import "${args[@]}" "$selected_guid" || return 1
  pools+=("$pool")
  save_state
}

load_zfs_key() {
  local dataset=$1 enc_root location key_file attempt
  enc_root=$(zfs get -H -o value encryptionroot "$dataset")
  [ "$enc_root" != - ] || return 0
  [ "$(zfs get -H -o value keystatus "$enc_root")" = unavailable ] || return 0
  location=$(zfs get -H -o value keylocation "$enc_root")
  if [[ $location == file://* ]]; then
    # Key files are paths on the host's own file systems, now under $root.
    key_file=$root${location#file://}
    if [ -f "$key_file" ]; then
      zfs load-key -L "file://$key_file" "$enc_root"
      return
    fi
  fi
  for attempt in 1 2 3; do
    zfs load-key -L prompt "$enc_root" && return 0
    log "Attempt $attempt/3 failed"
  done
  err "could not load the key of $enc_root"
}

open_luks() {
  local name=$1 device key_file resolved args=(open)
  [ ! -e "/dev/mapper/$name" ] || return 0
  device=$(jq -r --arg name "$name" '.luks[$name].device // empty' <<<"$host_json")
  [ -n "$device" ] || err "/dev/mapper/$name is not a LUKS device of $host"
  resolve_device "$device"
  if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
    err "$device for LUKS device $name not found"
  fi
  key_file=$(jq -r --arg name "$name" '.luks[$name].keyFile // empty' <<<"$host_json")
  [ "$mode" = rw ] || args+=(--readonly)
  # Initrd key files under /sysroot live on the host's own file systems.
  if [ -n "$key_file" ] && [ -f "$root${key_file#/sysroot}" ]; then
    args+=(--key-file "$root${key_file#/sysroot}")
  fi
  cryptsetup "${args[@]}" "$resolved" "$name"
  luks+=("$name")
  save_state
}

mount_options() {
  local fs_type=$1 options=$2
  if [ "$mode" = ro ]; then
    # Never replay journals or logs: read-only must not write to the disk.
    case $fs_type in
      btrfs) options+=,ro,rescue=nologreplay ;;
      ext4) options+=,ro,noload ;;
      xfs) options+=,ro,norecovery ;;
      tmpfs) ;;
      *) options+=,ro ;;
    esac
  fi
  echo "${options#,}"
}

mount_fs() {
  local mount_point=$1 device=$2 fs_type=$3 options resolved
  options=$(mount_options "$fs_type" "$4")
  if [ "$fs_type" = zfs ]; then
    import_pool "${device%%/*}" || err "could not import pool ${device%%/*}"
    load_zfs_key "$device"
  elif [[ $device == /dev/mapper/* ]]; then
    open_luks "${device#/dev/mapper/}"
  elif [[ $device == /dev/* ]]; then
    resolve_device "$device"
    if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
      if [[ ,$4, == *,nofail,* ]]; then
        log "warning: $device for $mount_point is missing; skipping it (nofail)"
        return
      fi
      err "$device for $mount_point not found"
    fi
    device=$resolved
  fi

  if [ "$mount_point" = / ] && [ "$mode" = ro ]; then
    # Rolled-back roots are empty and the disk is read-only: overlay a RAM
    # layer so mount points and scratch files never touch the disk.
    mkdir -p "$lower" "$upper"
    mount -t "$fs_type" -o "$options" "$device" "$lower"
    mount -t tmpfs -o mode=0755 rescue-upper "$upper"
    mkdir -p "$upper/data" "$upper/work" "$root"
    mount -t overlay rescue-root \
      -o "lowerdir=$lower,upperdir=$upper/data,workdir=$upper/work" "$root"
    return
  fi
  mkdir -p "$root$mount_point"
  mount -t "$fs_type" -o "$options" "$device" "$root$mount_point"
}

# Datasets the host mounts through zfs-mount.service rather than fileSystems.
mount_pool_datasets() {
  local pool=$1 name mount_point can_mount mounted
  while IFS=$'\t' read -r -u 4 name mount_point can_mount mounted; do
    if [ "$can_mount" != on ] || [ "$mounted" != no ]; then
      continue
    fi
    case $mount_point in legacy | none) continue ;; esac
    load_zfs_key "$name"
    zfs mount "$name" || log "warning: could not mount $name"
  done 4< <(zfs list -H -t filesystem -r -s mountpoint -o name,mountpoint,canmount,mounted "$pool")
}

# Impermanence binds these with systemd at boot; recreate them so the tree
# matches the running host and chroot tools find their state.
bind_persistence() {
  local source target
  while IFS=$'\t' read -r -u 3 source target; do
    [ -d "$root$source" ] || continue
    if mountpoint -q "$root$target"; then
      continue
    fi
    if ! { mkdir -p "$root$target" && mount --bind "$root$source" "$root$target"; } 2>/dev/null; then
      log "warning: could not bind $source to $target"
    fi
  done 3< <(jq -r '.binds[] | [.source, .target] | @tsv' <<<"$host_json")
}

unlock_identity() {
  local key public
  key=$(field .sshKey)
  if [ -z "$key" ] || [ ! -f "$root$key" ]; then
    identity=missing
  else
    public=$(ssh-keygen -y -f "$root$key" | cut -d' ' -f1,2)
    if ! jq -e --arg key "$public" \
      '.hostKeys | map(split(" ")[:2] | join(" ")) | index($key) != null' \
      <<<"$host_json" >/dev/null; then
      identity=mismatch
    elif ! systemctl cat sops-install-secrets.service >/dev/null 2>&1; then
      identity=none
    else
      ln -sfn "$root$key" "$host_key_link"
      if systemctl restart sops-install-secrets.service; then
        identity=unlocked
      else
        identity=failed
      fi
    fi
  fi
  save_state
  # A key from another host means these are not $host's disks.
  if [ "$identity" = mismatch ] && [ "$mode" = rw ]; then
    err "the host key on these disks does not match $host in secrets/pubkeys.nix; refusing read-write"
  fi
}

do_unlock() {
  local host_id mount_point device fs_type options pool
  save_state
  host_id=$(field .hostId)
  if [ -n "$host_id" ] && [ "$(jq '.pools + .extraPools | length' <<<"$host_json")" -gt 0 ]; then
    # Import as the host itself: no forced import, and pool labels keep its
    # host id even if the machine loses power before `rescue lock`.
    modprobe zfs
    hostid_orig=$(<"$spl_hostid")
    save_state
    echo "$((16#$host_id))" >"$spl_hostid"
  fi

  while IFS=$'\t' read -r -u 3 mount_point device fs_type options; do
    mount_fs "$mount_point" "$device" "$fs_type" "$options"
  done 3< <(jq -r '.fileSystems[] | [.mountPoint, .device, .fsType, (.options | join(","))] | @tsv' <<<"$host_json")

  while read -r -u 3 pool; do
    import_pool "$pool" || log "warning: could not import $pool; skipping it"
  done 3< <(jq -r '.extraPools[]' <<<"$host_json")
  for pool in "${pools[@]}"; do
    mount_pool_datasets "$pool"
  done

  bind_persistence
  if [ "$mode" = rw ]; then
    # nixos-enter refuses a root without this marker, and rolled-back roots
    # lack it until the host boots.
    mkdir -p "$root/etc"
    touch "$root/etc/NIXOS"
  fi
  unlock_identity
}

do_lock() {
  local i
  systemctl stop sops-install-secrets.service 2>/dev/null || true
  if mountpoint -q "$secrets_mount"; then
    umount "$secrets_mount"
  fi
  rm -f "$secrets_link" "$host_key_link"
  rmdir "$secrets_mount" 2>/dev/null || true

  if mountpoint -q "$root"; then
    umount -R "$root" ||
      err "$root is busy; leave it and stop programs using it (fuser -vm $root), then run rescue lock again"
  fi
  for i in "$lower" "$upper"; do
    if mountpoint -q "$i"; then
      umount -R "$i"
    fi
  done
  for ((i = ${#pools[@]} - 1; i >= 0; i--)); do
    if zpool list "${pools[i]}" >/dev/null 2>&1; then
      zpool export "${pools[i]}"
    fi
  done
  for ((i = ${#luks[@]} - 1; i >= 0; i--)); do
    if [ -e "/dev/mapper/${luks[i]}" ]; then
      cryptsetup close "${luks[i]}"
    fi
  done
  if [ -n "$hostid_orig" ]; then
    echo "$hostid_orig" >"$spl_hostid"
  fi
  rm -f "$state_file"

  log "Locked $host"
  if [ "$(field .secureBoot)" = true ]; then
    log "Re-enable Secure Boot before booting $host, or its TPM unlock falls back to a passphrase prompt."
  fi
}

cmd_unlock() {
  local target='' want=ro status
  while [ $# -gt 0 ]; do
    case $1 in
      --rw) want=rw ;;
      -h | --help)
        usage
        return
        ;;
      -*) err "unknown option: $1" ;;
      *)
        [ -z "$target" ] || err "only one host can be unlocked at a time"
        target=$1
        ;;
    esac
    shift
  done
  if [ -z "$target" ]; then
    usage
    exit 1
  fi
  [ -n "$(host_entry "$target")" ] || err "unknown host: $target (known: $(host_names))"

  if load_state; then
    if [ "$host" = "$target" ] && [ "$mode" = "$want" ]; then
      log "$host is already unlocked"
      cmd_status
      return
    fi
    log "Locking $host first"
    do_lock
  fi

  host=$target mode=$want hostid_orig='' identity=locked
  pools=()
  luks=()
  chosen_disks=()
  host_json=$(host_entry "$host")

  # Run in a subshell so any failed step rolls back from the saved state.
  # errexit is ignored in tested contexts, so capture the status explicitly.
  set +e
  (
    set -e
    do_unlock
  )
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    log "Unlock failed; rolling back"
    load_state && do_lock
    exit 1
  fi
  load_state
  cmd_status
}

cmd_lock() {
  if ! load_state; then
    log "Nothing is unlocked"
    return
  fi
  do_lock
}

describe_identity() {
  case $identity in
    unlocked) echo "unlocked with the host key ($secrets_link)" ;;
    mismatch) echo "locked: host key does not match secrets/pubkeys.nix" ;;
    missing) echo "locked: host key not found" ;;
    failed) echo "locked: decryption failed (journalctl -u sops-install-secrets)" ;;
    none) echo "none on this image" ;;
    *) echo locked ;;
  esac
}

cmd_status() {
  local persist host_system access=read-only
  printf '%-9s %s\n' Revision "$(jq -r .revision "$RESCUE_MANIFEST")"
  if ! load_state; then
    printf '%-9s %s\n' State locked Hosts "$(host_names)"
    return
  fi
  persist=$(field .persistPath)
  host_system=$(field .system)
  [ "$mode" != rw ] || access=read-write
  printf '%-9s %s\n' State unlocked Host "$host" Mode "$access" Root "$root"
  [ -z "$persist" ] || printf '%-9s %s\n' Persist "$root$persist"
  if [ "$host_system" != "$(jq -r .system "$RESCUE_MANIFEST")" ]; then
    printf '%-9s %s\n' System "$host_system: nixos-enter needs a $host_system image"
  fi
  printf '%-9s %s\n' Pools "${pools[*]:--}" LUKS "${luks[*]:--}" Secrets "$(describe_identity)"
}

command=${1:-}
[ $# -eq 0 ] || shift
case $command in
  unlock | lock)
    [ "$(id -u)" -eq 0 ] || exec sudo "$0" "$command" "$@"
    "cmd_$command" "$@"
    ;;
  status) cmd_status ;;
  help | -h | --help) usage ;;
  '')
    usage
    exit 1
    ;;
  *)
    usage
    err "unknown command: $command"
    ;;
esac
