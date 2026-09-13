# Included by writeShellApplication; firmware paths come from the locked NUR input.
set -euo pipefail
export LC_ALL=C
EC_FIRMWARE='@ecFirmware@'
COREBOOT_FIRMWARE='@corebootFirmware@'

fail() { echo "redrix-flash: $*" >&2; exit 1; }
ec() { ectool --interface=dev --name=cros_ec "$@"; }
usage() {
  cat <<'HELP'
Usage: redrix-flash status
       redrix-flash {ec-rw|coreboot} --backup-dir /persistent/path [--dry-run] [--yes]

status    Show the device, installed EC version, and packaged firmware revisions.
ec-rw     Back up the EC, replace and verify RW, then queue activation at shutdown.
coreboot  Back up the BIOS chip, preserve device data, and update the BIOS region.

Run as root. Connect AC power and keep the backup directory on persistent storage.
--dry-run performs reads and prepares files without changing firmware or drivers.
--yes skips the final confirmation. No command reboots the computer automatically.
After ec-rw succeeds, shut down normally, then power on to activate the new EC.
HELP
}

command=${1:-status}
if [[ "$command" == --help || "$command" == -h ]]; then usage; exit 0; fi
(( $# == 0 )) || shift
backup_dir=
dry_run=false
yes=false
while (( $# )); do
  case "$1" in
    --backup-dir) (( $# >= 2 )) || fail 'Missing backup directory'; backup_dir=$2; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --yes) yes=true; shift ;;
    *) fail "Unknown option: $1" ;;
  esac
done
case "$command" in status|ec-rw|coreboot) ;; *) usage; exit 1 ;; esac
[[ $(cat /sys/class/dmi/id/sys_vendor) == Google &&
   $(cat /sys/class/dmi/id/product_name) == Redrix ]] || fail 'This app supports Google Redrix only'
(( EUID == 0 )) || fail 'Run with sudo nix run .#redrix-flash -- ...'

if [[ "$command" == status ]]; then
  printf 'Device: Google Redrix\nInstalled BIOS: %s\n' "$(cat /sys/class/dmi/id/bios_version)"
  ec version
  ec flashprotect
  ec sysinfo
  printf '\nPackaged coreboot: %s\nPackaged EC: %s\n' \
    "$(cat "$COREBOOT_FIRMWARE/source-revision")" "$(cat "$EC_FIRMWARE/source-revision")"
  exit 0
fi
[[ "$backup_dir" == /* ]] || fail 'Supply an absolute --backup-dir on persistent storage'

exec 9>/run/redrix-flash.lock
flock -n 9 || fail 'Another redrix-flash process is running'

ac_online=false
for supply in /sys/class/power_supply/*; do
  if [[ -f "$supply/online" && $(cat "$supply/online") == 1 ]]; then ac_online=true; fi
done
[[ "$ac_online" == true ]] || fail 'Connect AC power before updating firmware'
umask 077
mkdir -p "$backup_dir"
work=$(mktemp -d "$backup_dir/redrix-$command-$(date +%Y%m%d-%H%M%S).XXXXXX")
exec > >(tee "$work/session.log") 2>&1
printf 'Backup and prepared image directory: %s\n' "$work"
fwupd_override=
fwupd_restart=false
writing=false
pause_fwupd() {
  local state
  state=$(systemctl show --property=LoadState --value fwupd.service) || fail 'Cannot determine fwupd service state'
  case "$state" in
    not-found) return ;;
    masked)
      if systemctl is-active --quiet fwupd.service; then
        fail 'fwupd is active but already masked; stop it before flashing'
      fi
      return ;;
    loaded) ;;
    *) fail "Unsupported fwupd service state: $state" ;;
  esac
  if systemctl is-active --quiet fwupd.service; then fwupd_restart=true; fi
  # A runtime mask cannot override NixOS's unit symlink in /etc. A temporary
  # start condition also prevents D-Bus activation, without replacing the unit.
  mkdir -p /run/systemd/system/fwupd.service.d
  fwupd_override=$(mktemp /run/systemd/system/fwupd.service.d/redrix-flash-XXXXXX.conf)
  printf '[Unit]\nConditionPathExists=!%s\n' "$fwupd_override" > "$fwupd_override"
  systemctl daemon-reload
  systemctl stop fwupd.service
}
cleanup() {
  local rc=$?
  if [[ "$writing" == true ]]; then
    echo "Firmware update did not finish. Do not reboot; keep $work for recovery." >&2
  fi
  if [[ -n "$fwupd_override" ]]; then
    if ! rm -f "$fwupd_override" || ! systemctl daemon-reload; then
      echo "Could not remove the temporary fwupd start condition: $fwupd_override" >&2
      rc=1
    fi
  fi
  if [[ "$fwupd_restart" == true ]]; then
    if ! systemctl start fwupd.service; then
      echo 'Could not restart fwupd.' >&2
      rc=1
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
confirm() {
  sync
  [[ "$dry_run" == false ]] || { echo 'Dry run complete; no device changes made.'; exit 0; }
  echo "Ready to flash $command. Backup: $work"
  if [[ "$yes" == false ]]; then
    local answer
    read -r -p 'Type FLASH to proceed: ' answer
    [[ "$answer" == FLASH ]] || fail 'Cancelled'
  fi
}
check_ec() {
  local version info flags copy
  version=$(ec version)
  printf '%s\n' "$version"
  grep -qE '^RO version:[[:space:]]+redrix_' <<< "$version" || fail 'Unexpected EC board'
  # Redrix's NPCX9 executes from SRAM, allowing RW flash updates while RW runs.
  # Do not apply this sequence to an EC that executes directly from flash.
  info=$(ec chipinfo)
  printf '%s\n' "$info"
  grep -qE '^[[:space:]]+vendor:[[:space:]]+Nuvoton$' <<< "$info" || fail 'Unsupported EC vendor'
  grep -qE '^[[:space:]]+name:[[:space:]]+NPCX993F$' <<< "$info" || fail 'Unsupported EC chip for live RW update'
  info=$(ec flashinfo)
  grep -qx 'FlashSize 524288' <<< "$info" || fail 'Unexpected EC flash size'
  grep -qx 'EraseSize 65536' <<< "$info" || fail 'Unexpected EC erase geometry'
  flags=$(ec flashprotect)
  printf '%s\n' "$flags"
  # RO protection is expected; ALL/RW protection and error flags forbid writing.
  flags=$(sed -nE 's/^Flash protect flags:[[:space:]]+(0x[0-9a-fA-F]+).*/\1/p' <<< "$flags")
  [[ "$flags" =~ ^0x[0-9a-fA-F]+$ ]] || fail 'Cannot read EC protection flags'
  (( (flags & ~0x0b) == 0 )) || fail 'EC RW is protected or protection state is unsupported'
  copy=$(sed -nE 's/^Firmware copy:[[:space:]]+(RO|RW)$/\1/p' <<< "$version")
  [[ "$copy" == RO || "$copy" == RW ]] || fail 'Cannot determine the running EC image'
  flags=$(ec_system_flags)
  printf 'EC system flags: %s\n' "$flags"
  # A previously queued reset must not activate an incomplete image if we fail.
  (( (flags & 0x10) == 0 )) || fail 'EC already has a reboot queued for shutdown; complete that shutdown before another update'
}
ec_system_flags() {
  local flags
  flags=$(ec sysinfo flags) || fail 'Cannot read EC system flags'
  [[ "$flags" =~ ^0x[0-9a-fA-F]+$ ]] || fail 'Cannot parse EC system flags'
  printf '%s\n' "$flags"
}

if [[ "$command" == ec-rw ]]; then
  (cd "$EC_FIRMWARE"; sha256sum -c SHA256SUMS)
  check_ec
  ec flashread 0 524288 "$work/ec.before.bin"
  [[ $(stat -c %s "$work/ec.before.bin") == 524288 ]] || fail 'Incomplete EC backup'
  dd if="$EC_FIRMWARE/ec.bin" of="$work/ec.RW.bin" bs=262144 skip=1 count=1 status=none
  [[ $(stat -c %s "$work/ec.RW.bin") == 262144 ]] || fail 'Invalid packaged RW image'
  (cd "$work"; sha256sum ec.before.bin ec.RW.bin > SHA256SUMS)
  confirm
  check_ec
  writing=true
  ec flasherase 262144 262144
  ec flashwrite 262144 "$work/ec.RW.bin"
  ec flashread 0 524288 "$work/ec.after.bin"
  cmp -n 262144 "$work/ec.before.bin" "$work/ec.after.bin"
  dd if="$work/ec.after.bin" of="$work/ec.RW.readback.bin" bs=262144 skip=1 count=1 status=none
  cmp "$work/ec.RW.bin" "$work/ec.RW.readback.bin"
  writing=false
  echo 'EC RW flashed and verified; EC RO is unchanged.'
  # The old firmware continues running from SRAM. Jumping to the same image
  # is a no-op, and a locked EC denies RW -> RO. Reset only at a clean shutdown.
  ec reboot_ec cold at-shutdown || fail 'RW is verified, but queuing the EC reset failed; activation is pending'
  flags=$(ec_system_flags)
  (( (flags & 0x10) != 0 )) || fail 'RW is verified, but the EC did not confirm a reset queued for shutdown'
  echo 'EC reset queued. Save your work, shut down normally, then power on to activate the new RW.'
  exit 0
fi

[[ $(cat /sys/class/dmi/id/bios_vendor) == coreboot ]] || fail 'An existing coreboot UEFI installation is required'
# Accept package versions as well as the previous prefixed builds.
bios_version=$(cat /sys/class/dmi/id/bios_version)
case "$bios_version" in
  MrChromebox-*|nur-*) ;;
  *)
    [[ "$bios_version" =~ ^[0-9]+(\.[0-9]+)+(-unstable\.[0-9]+)?-g[0-9a-f]{12}$ ]] ||
      fail 'An existing MrChromebox or NUR Redrix UEFI installation is required' ;;
esac
(cd "$COREBOOT_FIRMWARE"; sha256sum -c SHA256SUMS)
grep -qx CONFIG_BOARD_GOOGLE_REDRIX=y "$COREBOOT_FIRMWARE/coreboot.config" || fail 'Packaged firmware is not for Redrix'
# Use the internal programmer, as MrChromebox does. A full read preserves a
# complete backup; writes below are restricted to the live IFD's BIOS region.
flashrom -p internal -r "$work/coreboot.before.rom"
[[ $(stat -c %s "$work/coreboot.before.rom") == 33554432 ]] || fail 'Incomplete BIOS backup'
cp "$COREBOOT_FIRMWARE/coreboot.rom" "$work/coreboot.prepared.rom"
chmod u+w "$work/coreboot.prepared.rom"
for image in before prepared; do
  ifdtool -p adl -f "$work/$image.layout" "$work/coreboot.$image.rom"
  grep -qx '00500000:01ffffff bios' "$work/$image.layout" || fail 'Unsupported BIOS region layout'
  cbfstool "$work/coreboot.$image.rom" print > "$work/$image.cbfs"
done
# Preserve the descriptor and ME even in the prepared file, although flashrom
# only writes the BIOS range from the current device's descriptor.
dd if="$work/coreboot.before.rom" of="$work/coreboot.prepared.rom" bs=1M count=5 conv=notrunc status=none
for region in SMMSTORE RO_VPD RW_MRC_CACHE; do
  cbfstool "$work/coreboot.before.rom" read -r "$region" -f "$work/$region.bin"
  cbfstool "$work/coreboot.prepared.rom" write -r "$region" -f "$work/$region.bin"
done
for name in serial_number hwid vpd.bin; do
  if cut -d ' ' -f1 "$work/before.cbfs" | grep -qxF "$name"; then
    cbfstool "$work/coreboot.before.rom" extract -n "$name" -f "$work/$name"
    if cut -d ' ' -f1 "$work/prepared.cbfs" | grep -qxF "$name"; then
      cbfstool "$work/coreboot.prepared.rom" remove -n "$name"
    fi
    cbfstool "$work/coreboot.prepared.rom" add -n "$name" -t raw -f "$work/$name"
  fi
done
cbfstool "$work/coreboot.prepared.rom" extract -n ecrw -f "$work/ecrw.bin"
cmp "$EC_FIRMWARE/ec.RW.flat" "$work/ecrw.bin"
(cd "$work"; sha256sum coreboot.before.rom coreboot.prepared.rom > SHA256SUMS)
confirm
pause_fwupd
writing=true
flashrom -p internal --ifd -i bios \
  --noverify-all -w "$work/coreboot.prepared.rom"
writing=false
echo 'Coreboot BIOS region flashed and verified. Reboot when ready.'
