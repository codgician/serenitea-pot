{
  lib,
  pkgs,
  ...
}:
let
  name = "dbxmgr";

  # Map Nix platform to Microsoft's signed DBX asset.
  # v1.7.0 ships authenticated EFI updates under edk2-2023.
  dbxAsset =
    {
      "x86_64-linux" = "edk2-2023/dbx_x64.efiauth2";
      "aarch64-linux" = "edk2-2023/dbx_aarch64.efiauth2";
      "i686-linux" = "edk2-2023/dbx_ia32.efiauth2";
      "armv7l-linux" = "edk2-2023/dbx_arm.efiauth2";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${pkgs.stdenv.hostPlatform.system}");

  # Keep the Microsoft architecture name for status output.
  msftArch =
    {
      "x86_64-linux" = "amd64";
      "aarch64-linux" = "arm64";
      "i686-linux" = "x86";
      "armv7l-linux" = "arm";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${pkgs.stdenv.hostPlatform.system}");

  # DBX EFI variable GUID
  dbxGuid = "d719b2cb-3d3a-4596-a3bc-dad00e67656f";
  securebootObjects = pkgs.nur.repos.codgician.secureboot-objects;
  securebootObjectsDir = "${securebootObjects}/share/secureboot-objects";
  helpText = ''
    ${name} - Manage UEFI Secure Boot DBX (revocation database)

    USAGE: ${name} <command> [options]

    COMMANDS:
      status      Show current DBX status and available updates
      apply       Apply a DBX update from a specified file
      update      Apply the packaged DBX update (with confirmation)

    OPTIONS:
      -h, --help      Show this help
      -y, --yes       Skip confirmation prompts

    EXAMPLES:
      ${name} status              # Check if DBX needs updating
      ${name} apply /tmp/dbx.bin  # Apply a specific DBX file
      ${name} update              # Apply the packaged DBX update

    NOTES:
      - Requires root privileges for 'apply' and 'update' commands
      - DBX updates are signed by Microsoft and verified before apply
      - Source: https://github.com/microsoft/secureboot_objects

    WARNING:
      Applying an incorrect DBX update can prevent your system from booting.
      Always ensure your bootloader (shim/grub) is up to date before updating DBX.
  '';
in
{
  type = "app";
  meta = {
    description = "Manage UEFI Secure Boot DBX revocation database";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        coreutils
        e2fsprogs # for chattr
        efitools
        gnugrep
        python3
      ];
      text = ''
                        set -euo pipefail

                        ARCH="${msftArch}"
                        DBX_GUID="${dbxGuid}"
                        DBX_SOURCE="${securebootObjectsDir}/${dbxAsset}"
                        DBX_VERSION="${securebootObjects.version}"
                        DBX_VAR_PATH="/sys/firmware/efi/efivars/dbx-$DBX_GUID"

                        # Colors
                        RED='\033[0;31m'
                        GREEN='\033[0;32m'
                        YELLOW='\033[1;33m'
                        NC='\033[0m' # No Color

                        err() { echo -e "''${RED}Error:''${NC} $*" >&2; exit 1; }
                        warn() { echo -e "''${YELLOW}Warning:''${NC} $*" >&2; }
                        info() { echo -e "''${GREEN}→''${NC} $*" >&2; }
                        log() { echo "$*" >&2; }

                        show_help() {
                          cat >&2 <<'EOF'
                        ${helpText}
        EOF
                        }

                        # Check if Microsoft KEK is enrolled
                        has_microsoft_kek() {
                          local kek_path="/sys/firmware/efi/efivars/KEK-8be4df61-93ca-11d2-aa0d-00e098032b8c"
                          [[ -f "$kek_path" ]] || return 1
                          efi-readvar -v KEK 2>/dev/null | grep -qi "Microsoft"
                        }

                        # Preflight checks
                        check_efi_support() {
                          [[ -d /sys/firmware/efi ]] || err "System not booted in UEFI mode"
                          [[ -d /sys/firmware/efi/efivars ]] || err "efivarfs not mounted"
                        }

                        # Get current DBX version/info
                        get_current_dbx() {
                          if [[ ! -f "$DBX_VAR_PATH" ]]; then
                            echo "not_enrolled"
                            return
                          fi

                          local size
                          size=$(stat -c%s "$DBX_VAR_PATH" 2>/dev/null || echo "0")
                          if [[ "$size" -le 4 ]]; then
                            echo "empty"
                            return
                          fi

                          # Count signature entries (rough estimate based on file size)
                          # Each SHA256 hash entry is ~48 bytes (16 GUID + 32 hash)
                          local entries=$(( (size - 4) / 48 ))
                          echo "enrolled:$size:$entries"
                        }

                        # Apply DBX update
                        apply_dbx() {
                          local dbx_file="$1"

                          [[ -f "$dbx_file" ]] || err "DBX file not found: $dbx_file"
                          [[ $EUID -eq 0 ]] || err "Root privileges required to apply DBX update"
                          check_efi_support

                          local file_size
                          file_size=$(stat -c%s "$dbx_file")
                          [[ "$file_size" -gt 100 ]] || err "DBX file appears too small: $file_size bytes"

                          info "Applying DBX update: $dbx_file ($file_size bytes)"

                          # Check and remove immutable flag if needed (stateful)
                          local was_immutable=0
                          if [[ -f "$DBX_VAR_PATH" ]]; then
                            if lsattr "$DBX_VAR_PATH" 2>/dev/null | grep -q 'i'; then
                              was_immutable=1
                              info "Removing immutable flag from DBX variable..."
                              chattr -i "$DBX_VAR_PATH" || err "Failed to remove immutable flag"
                            fi
                            # Restore immutable on exit if we changed it
                            if [[ "$was_immutable" -eq 1 ]]; then
                              # shellcheck disable=SC2064
                              trap "chattr +i '$DBX_VAR_PATH' 2>/dev/null || true; trap - EXIT INT TERM" EXIT INT TERM
                            fi
                          fi

                          # Apply the authenticated update with append mode
                          # Firmware validates signature against KEK
                          efi-updatevar -a -f "$dbx_file" dbx || err "Failed to apply DBX update"

                          # Restore immutable flag if we changed it
                          if [[ "$was_immutable" -eq 1 ]] && [[ -f "$DBX_VAR_PATH" ]]; then
                            info "Restoring immutable flag on DBX variable..."
                            chattr +i "$DBX_VAR_PATH" || warn "Failed to restore immutable flag"
                          fi
                          trap - EXIT INT TERM

                          info "DBX update applied successfully!"
                          info "Verifying..."
                          show_status || true
                        }

                        # Emit canonical EFI signature records from a DBX variable/update.
                        # The current variable starts with 4-byte EFI attributes; authenticated
                        # updates start with EFI_TIME plus a WIN_CERTIFICATE wrapper.
                        dbx_records() {
                          local file="$1" format="$2"
                          python3 - "$file" "$format" <<'PY'
        import struct
        import sys

        path, fmt = sys.argv[1:]
        data = open(path, "rb").read()
        offset = 4 if fmt == "raw" else 16 + struct.unpack_from("<I", data, 16)[0]

        while offset + 28 <= len(data):
            sig_type = data[offset:offset + 16]
            list_size, header_size, sig_size = struct.unpack_from("<III", data, offset + 16)
            if list_size < 28 + header_size or sig_size == 0:
                raise SystemExit(f"invalid EFI signature list in {path}")
            end = offset + list_size
            records_start = offset + 28 + header_size
            if end > len(data) or records_start > end:
                raise SystemExit(f"truncated EFI signature list in {path}")
            for record_start in range(records_start, end, sig_size):
                record_end = record_start + sig_size
                if record_end > end:
                    raise SystemExit(f"truncated EFI signature record in {path}")
                print(f"{sig_type.hex()}:{data[record_start:record_end].hex()}")
            offset = end
        PY
                        }

                        count_dbx_entries() {
                          local file="$1" format="$2"
                          dbx_records "$file" "$format" | wc -l
                        }

                        count_missing_dbx_entries() {
                          local update_file="$1" current_file="$2" temp_dir missing
                          temp_dir=$(mktemp -d)
                          dbx_records "$update_file" authenticated | sort -u > "$temp_dir/update"
                          dbx_records "$current_file" raw | sort -u > "$temp_dir/current"
                          missing=$(comm -23 "$temp_dir/update" "$temp_dir/current" | wc -l)
                          rm -rf "$temp_dir"
                          echo "$missing"
                        }

                        # Hash the DBX payload (for comparison)
                        get_dbx_hash() {
                          local file="$1" skip_bytes
                          
                          if [[ "$file" == /sys/firmware/efi/* ]]; then
                            skip_bytes=5  # 4-byte attributes + 1 (tail is 1-indexed)
                          else
                            local auth_len
                            auth_len=$(od -An -tu4 -j16 -N4 "$file" | tr -d ' ')
                            skip_bytes=$((16 + auth_len + 1))
                          fi
                          
                          tail -c +"$skip_bytes" "$file" | sha256sum | cut -d' ' -f1
                        }

                        # Show current status with comparison
                        show_status() {
                          log ""
                          log "=== DBX Status ==="
                          log ""

                          # Current DBX info
                          local current_status current_size current_entries current_hash
                          current_status=$(get_current_dbx)

                          case "$current_status" in
                            not_enrolled)
                              log "Current DBX:  NOT ENROLLED"
                              warn "No DBX variable found - system may be vulnerable"
                              current_hash="none"
                              current_entries=0
                              ;;
                            empty)
                              log "Current DBX:  EMPTY"
                              warn "DBX variable exists but contains no entries"
                              current_hash="empty"
                              current_entries=0
                              ;;
                            enrolled:*)
                              current_size=$(echo "$current_status" | cut -d: -f2)
                              current_entries=$(count_dbx_entries "$DBX_VAR_PATH" raw)
                              current_hash=$(get_dbx_hash "$DBX_VAR_PATH")
                              log "Current DBX:  ENROLLED"
                              log "  Size:       $current_size bytes"
                              log "  Entries:    ~$current_entries revoked signatures"
                              log "  Hash:       ''${current_hash:0:16}..."
                              ;;
                          esac

                          log ""
                          log "Architecture:   $ARCH"
                          log ""

                          # Compare with the update supplied by the pinned NUR package
                          info "Reading packaged DBX update..."

                          local latest_file="$DBX_SOURCE"
                          [[ -f "$latest_file" ]] || {
                            warn "Packaged DBX update not found for architecture: $ARCH"
                            return 1
                          }

                          local latest_hash latest_entries latest_size
                          latest_size=$(stat -c%s "$latest_file")
                          latest_entries=$(count_dbx_entries "$latest_file" authenticated)
                          latest_hash=$(get_dbx_hash "$latest_file")
                          local missing_entries
                          missing_entries=$(count_missing_dbx_entries "$latest_file" "$DBX_VAR_PATH")

                          log "Packaged ($DBX_VERSION):"
                          log "  Size:       $latest_size bytes"
                          log "  Entries:    ~$latest_entries revoked signatures"
                          log "  Hash:       ''${latest_hash:0:16}..."
                          log "  Source:     ${securebootObjects.meta.changelog}"
                          log ""

                          if [[ "$current_hash" == "none" ]] || [[ "$current_hash" == "empty" ]]; then
                            echo -e "''${RED}Status: UPDATE REQUIRED''${NC} - DBX not enrolled"
                            return 1
                          elif [[ "$missing_entries" -eq 0 ]]; then
                            echo -e "''${GREEN}Status: UP TO DATE''${NC}"
                            log "  Packaged records already present: $latest_entries"
                            return 0
                          else
                            echo -e "''${YELLOW}Status: UPDATE AVAILABLE''${NC}"
                            log "  Missing packaged records: $missing_entries"
                            return 1
                          fi
                        }

                        # Main
                        auto_yes=0
                        command=""
                        args=()

                        while [[ $# -gt 0 ]]; do
                          case $1 in
                            -h|--help) show_help; exit 0 ;;
                            -y|--yes) auto_yes=1; shift ;;
                            -*) err "Unknown option: $1" ;;
                            *)
                              if [[ -z "$command" ]]; then
                                command="$1"
                              else
                                args+=("$1")
                              fi
                              shift
                              ;;
                          esac
                        done

                        [[ -n "$command" ]] || { show_help; exit 1; }
                        case "$command" in
                          status)
                            show_status
                            ;;

                          apply)
                            [[ ''${#args[@]} -ge 1 ]] || err "Usage: ${name} apply <dbx-file>"
                            dbx_file="''${args[0]}"

                            if [[ "$auto_yes" -eq 0 ]]; then
                              warn "This will modify your system's Secure Boot DBX database."
                              warn "Ensure your bootloader is up to date before proceeding."
                              read -r -p "Continue? [y/N] " confirm
                              [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
                            fi

                            apply_dbx "$dbx_file"
                            ;;

                          update)
                            check_efi_support
                            
                            # Warn if Microsoft KEK not detected (firmware will be final arbiter)
                            if ! has_microsoft_kek; then
                              warn "Microsoft KEK not detected - update may fail if not enrolled"
                            fi

                            # Check if update is needed
                            if show_status; then
                              log ""
                              info "No update needed."
                              exit 0
                            fi

                            if [[ "$auto_yes" -eq 0 ]]; then
                              log ""
                              warn "This will modify your system's Secure Boot DBX database."
                              warn "Ensure your bootloader is up to date before proceeding."
                              read -r -p "Apply update now? [y/N] " confirm
                              [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
                            fi

                            apply_dbx "$DBX_SOURCE"
                            ;;

                          *)
                            err "Unknown command: $command"
                            ;;
                        esac
      '';
    }
  );
}
