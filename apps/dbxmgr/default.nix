{
  lib,
  pkgs,
  ...
}:
let
  name = "dbxmgr";

  # Map Nix platform to Microsoft release asset directory name
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
  helpText = ''
    ${name} - Manage UEFI Secure Boot DBX (revocation database)

    USAGE: ${name} <command> [options]

    COMMANDS:
      status      Show current DBX status and available updates
      fetch       Download latest DBX update (does not apply)
      apply       Apply a previously fetched DBX update
      update      Fetch and apply in one step (with confirmation)

    OPTIONS:
      -h, --help      Show this help
      -y, --yes       Skip confirmation prompts
      --arch ARCH     Override architecture (default: ${msftArch})

    EXAMPLES:
      ${name} status              # Check if DBX needs updating
      ${name} fetch               # Download latest DBX to /tmp
      ${name} apply /tmp/dbx.bin  # Apply a specific DBX file
      ${name} update              # Fetch and apply with confirmation

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
        curl
        e2fsprogs # for chattr
        efitools
        findutils
        gawk
        gnugrep
        jq
        unzip
      ];

      text = ''
        set -euo pipefail

        ARCH="${msftArch}"
        GITHUB_REPO="microsoft/secureboot_objects"
        DBX_GUID="${dbxGuid}"
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

        # Fetch latest release info from GitHub
        get_latest_release() {
          local release_info
          release_info=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/releases/latest") || err "Failed to fetch release info"
          echo "$release_info"
        }

        # Extract version tag from release
        get_release_version() {
          local release_info="$1"
          echo "$release_info" | jq -r '.tag_name // empty' || err "Failed to parse release version"
        }

        # Get download URL for the release zip
        get_release_url() {
          local release_info="$1"
          echo "$release_info" | jq -r '.zipball_url // empty' || err "Failed to parse release URL"
        }

        # Download and extract DBX binary for specified arch
        fetch_dbx() {
          local arch="$1"
          local output_dir="$2"

          info "Fetching latest release info..."
          local release_info
          release_info=$(get_latest_release)

          local version
          version=$(get_release_version "$release_info")
          [[ -n "$version" ]] || err "Could not determine latest version"
          info "Latest version: $version"

          local zip_url
          zip_url=$(get_release_url "$release_info")
          [[ -n "$zip_url" ]] || err "Could not get download URL"

          local tmp_dir
          tmp_dir=$(mktemp -d)
          # shellcheck disable=SC2064
          trap "rm -rf '$tmp_dir'" EXIT

          info "Downloading release archive..."
          curl -sL "$zip_url" -o "$tmp_dir/release.zip" || err "Failed to download release"

          info "Extracting..."
          unzip -q "$tmp_dir/release.zip" -d "$tmp_dir" || err "Failed to extract release"

          # Find the DBX binary for our arch
          local dbx_file
          dbx_file=$(find "$tmp_dir" -path "*/$arch/DBXUpdate.bin" -type f | head -1)
          [[ -n "$dbx_file" ]] || err "DBXUpdate.bin not found for architecture: $arch"

          local output_file="$output_dir/DBXUpdate-$version-$arch.bin"
          cp "$dbx_file" "$output_file"

          # Version info is in the filename

          info "Downloaded: $output_file"
          echo "$output_file"
        }

        # Apply DBX update
        apply_dbx() {
          local dbx_file="$1"

          [[ -f "$dbx_file" ]] || err "DBX file not found: $dbx_file"
          [[ $EUID -eq 0 ]] || err "Root privileges required to apply DBX update"

          local file_size
          file_size=$(stat -c%s "$dbx_file")
          [[ "$file_size" -gt 100 ]] || err "DBX file appears too small: $file_size bytes"

          info "Applying DBX update: $dbx_file ($file_size bytes)"

          # Remove immutable flag from existing DBX variable if it exists
          # EFI variables in Linux have immutable flag set by default for safety
          if [[ -f "$DBX_VAR_PATH" ]]; then
            info "Removing immutable flag from DBX variable..."
            chattr -i "$DBX_VAR_PATH" || err "Failed to remove immutable flag (is secure boot in setup mode?)"
            
            # Set up trap to restore immutable flag on any exit (error, interrupt, etc.)
            # shellcheck disable=SC2064
            trap "chattr +i '$DBX_VAR_PATH' 2>/dev/null || true; trap - EXIT INT TERM" EXIT INT TERM
          fi

          # Apply the update
          efi-updatevar -a -f "$dbx_file" dbx || {
            err "Failed to apply DBX update"
          }

          # Restore immutable flag (trap will also fire, but be explicit)
          if [[ -f "$DBX_VAR_PATH" ]]; then
            info "Restoring immutable flag on DBX variable..."
            chattr +i "$DBX_VAR_PATH" || warn "Failed to restore immutable flag"
          fi
          
          # Clear the trap now that we've handled it
          trap - EXIT INT TERM

          info "DBX update applied successfully!"
          info "Verifying..."
          show_status || true
        }

        # Get payload size from a DBX file (excludes headers/wrappers)
        # - Sysfs files: 4-byte EFI attributes prefix
        # - Authenticated files: 16-byte timestamp + variable-length auth descriptor
        get_payload_size() {
          local file="$1" size
          size=$(stat -c%s "$file")
          
          if [[ "$file" == /sys/firmware/efi/* ]]; then
            echo $((size - 4))
          else
            # Auth descriptor length is a 4-byte little-endian int at offset 16
            local auth_len
            auth_len=$(od -An -tu4 -j16 -N4 "$file" | tr -d ' ')
            echo $((size - 16 - auth_len))
          fi
        }

        # Count approximate DBX entries (~48 bytes each: 16-byte GUID + 32-byte SHA256)
        count_dbx_entries() {
          local payload_size
          payload_size=$(get_payload_size "$1")
          echo $((payload_size / 48))
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
              current_entries=$(count_dbx_entries "$DBX_VAR_PATH")
              current_hash=$(get_dbx_hash "$DBX_VAR_PATH")
              log "Current DBX:  ENROLLED"
              log "  Size:       $current_size bytes"
              log "  Entries:    ~$current_entries revoked signatures"
              log "  Hash:       ''${current_hash:0:16}..."
              ;;
          esac

          log ""
          log "Architecture:   $arch"
          log ""

          # Fetch and compare with latest
          info "Fetching latest release for comparison..."
          
          local release_info version
          release_info=$(get_latest_release 2>/dev/null) || {
            warn "Could not fetch latest release info"
            return 1
          }
          version=$(get_release_version "$release_info")
          
          local zip_url tmp_dir
          zip_url=$(get_release_url "$release_info")
          tmp_dir=$(mktemp -d)
          # shellcheck disable=SC2064
          trap "rm -rf '$tmp_dir'" EXIT

          curl -sL "$zip_url" -o "$tmp_dir/release.zip" 2>/dev/null || {
            warn "Could not download release"
            return 1
          }
          unzip -q "$tmp_dir/release.zip" -d "$tmp_dir" 2>/dev/null || {
            warn "Could not extract release"
            return 1
          }

          local latest_file latest_hash latest_entries latest_size
          latest_file=$(find "$tmp_dir" -path "*/$arch/DBXUpdate.bin" -type f | head -1)
          
          if [[ -z "$latest_file" ]]; then
            warn "Could not find DBX for architecture: $arch"
            return 1
          fi

          latest_size=$(stat -c%s "$latest_file")
          latest_entries=$(count_dbx_entries "$latest_file")
          latest_hash=$(get_dbx_hash "$latest_file")

          log "Latest ($version):"
          log "  Size:       $latest_size bytes"
          log "  Entries:    ~$latest_entries revoked signatures"
          log "  Hash:       ''${latest_hash:0:16}..."
          log "  Source:     https://github.com/$GITHUB_REPO/releases/tag/$version"
          log ""

          # Compare
          if [[ "$current_hash" == "none" ]] || [[ "$current_hash" == "empty" ]]; then
            echo -e "''${RED}Status: UPDATE REQUIRED''${NC} - DBX not enrolled"
            return 1
          elif [[ "$current_hash" == "$latest_hash" ]]; then
            echo -e "''${GREEN}Status: UP TO DATE''${NC}"
            return 0
          else
            echo -e "''${YELLOW}Status: UPDATE AVAILABLE''${NC}"
            log "  Current:    ~$current_entries entries"
            log "  Latest:     ~$latest_entries entries (+$(( latest_entries - current_entries )) new)"
            return 1
          fi
        }

        # Main
        arch="$ARCH"
        auto_yes=0
        command=""
        args=()

        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help) show_help; exit 0 ;;
            -y|--yes) auto_yes=1; shift ;;
            --arch) arch="$2"; shift 2 ;;
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

          fetch)
            output_dir="''${args[0]:-/tmp}"
            fetch_dbx "$arch" "$output_dir"
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
            # Check if update is needed
            if show_status; then
              log ""
              info "No update needed."
              exit 0
            fi

            log ""
            info "Fetching latest DBX..."
            dbx_file=$(fetch_dbx "$arch" "/tmp")

            if [[ "$auto_yes" -eq 0 ]]; then
              log ""
              warn "This will modify your system's Secure Boot DBX database."
              warn "Ensure your bootloader is up to date before proceeding."
              read -r -p "Apply update now? [y/N] " confirm
              [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted. File saved at: $dbx_file"; exit 0; }
            fi

            apply_dbx "$dbx_file"
            ;;

          *)
            err "Unknown command: $command"
            ;;
        esac
      '';
    }
  );
}
