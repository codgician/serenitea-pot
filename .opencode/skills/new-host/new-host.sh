#!/usr/bin/env bash
# Bootstrap a new host in serenitea-pot
# Usage: ./new-host.sh <platform> <hostname> <arch> [type]
#
# Examples:
#   ./new-host.sh nixos nahida x86_64-linux container
#   ./new-host.sh darwin furina aarch64-darwin

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Validate arguments
platform="${1:-}"
hostname="${2:-}"
arch="${3:-}"
host_type="${4:-bare-metal}"

[[ -z "$platform" || -z "$hostname" || -z "$arch" ]] && {
    cat <<EOF
Usage: $0 <platform> <hostname> <arch> [type]

Arguments:
  platform   nixos | darwin
  hostname   Genshin character name (lowercase)
  arch       x86_64-linux | aarch64-linux | x86_64-darwin | aarch64-darwin
  type       bare-metal | vm | container | wsl (NixOS only, default: bare-metal)

Examples:
  $0 nixos wanderer x86_64-linux wsl
  $0 darwin furina aarch64-darwin
EOF
    exit 1
}

# Validate platform
[[ "$platform" != "nixos" && "$platform" != "darwin" ]] && \
    err "Platform must be 'nixos' or 'darwin', got: $platform"

# Validate arch matches platform
case "$platform" in
    nixos)
        [[ "$arch" != "x86_64-linux" && "$arch" != "aarch64-linux" ]] && \
            err "NixOS arch must be x86_64-linux or aarch64-linux, got: $arch"
        ;;
    darwin)
        [[ "$arch" != "x86_64-darwin" && "$arch" != "aarch64-darwin" ]] && \
            err "Darwin arch must be x86_64-darwin or aarch64-darwin, got: $arch"
        ;;
esac

# Determine paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOST_DIR="$REPO_ROOT/hosts/$platform/$hostname"

# Check if host already exists
[[ -d "$HOST_DIR" ]] && err "Host already exists: $HOST_DIR"

info "Creating host: $hostname ($platform, $arch)"

# Create directory
mkdir -p "$HOST_DIR"

# Generate default.nix
if [[ "$platform" == "nixos" ]]; then
    cat > "$HOST_DIR/default.nix" <<EOF
{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "$arch";
  modules = [
    ./system.nix
  ];
}
EOF
else
    cat > "$HOST_DIR/default.nix" <<EOF
{ lib, ... }:

lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  system = "$arch";
  modules = [
    ./system.nix
  ];
}
EOF
fi

# Generate system.nix based on platform and type
if [[ "$platform" == "nixos" ]]; then
    # NixOS system.nix
    type_config=""
    case "$host_type" in
        container)
            type_config=$'\n  boot.isContainer = true;'
            ;;
        wsl)
            type_config=$'\n  codgician.system.wsl.enable = true;'
            ;;
        vm|bare-metal)
            # Add hardware.nix to modules
            sed -i '' 's|./system.nix|./system.nix\n    ./hardware.nix|' "$HOST_DIR/default.nix" 2>/dev/null || \
            sed -i 's|./system.nix|./system.nix\n    ./hardware.nix|' "$HOST_DIR/default.nix"
            ;;
    esac

    cat > "$HOST_DIR/system.nix" <<'NIXEOF'
{ lib, pkgs, ... }:
{

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        opencode.enable = true;
        mcp.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        iperf3
      ];
    };

  # Global packages
  environment.systemPackages = [ ];

  # Enable zram swap
  zramSwap.enable = true;

  # Firewall
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
NIXEOF

    # Apply type-specific modifications
    case "$host_type" in
        container)
            sed -i '' '/^{$/a\
\  boot.isContainer = true;\
' "$HOST_DIR/system.nix" 2>/dev/null || \
            sed -i '/^{$/a\  boot.isContainer = true;' "$HOST_DIR/system.nix"
            ;;
        wsl)
            sed -i '' 's/auto-upgrade.enable = true;/auto-upgrade.enable = true;\n      wsl.enable = true;/' "$HOST_DIR/system.nix" 2>/dev/null || \
            sed -i 's/auto-upgrade.enable = true;/auto-upgrade.enable = true;\n      wsl.enable = true;/' "$HOST_DIR/system.nix"
            ;;
    esac

    # Create hardware.nix placeholder for bare-metal/vm
    if [[ "$host_type" == "bare-metal" || "$host_type" == "vm" ]]; then
        cat > "$HOST_DIR/hardware.nix" <<EOF
# Hardware configuration for $hostname
# Generate with: nixos-generate-config --show-hardware-config
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # TODO: Add hardware-specific configuration
  # boot.initrd.availableKernelModules = [ ... ];
  # boot.kernelModules = [ ... ];
}
EOF
    fi

else
    # Darwin system.nix
    cat > "$HOST_DIR/system.nix" <<EOF
{ config, lib, pkgs, ... }:

{
  codgician = {
    system.common.enable = true;
    system.brew = {
      enable = true;
      casks = [
        # GUI apps from Homebrew
      ];
      masApps = {
        # App Store apps: "Name" = id;
      };
    };
    users.codgi.enable = true;
  };

  system.primaryUser = "codgi";
  system.stateVersion = 6;
}
EOF
fi

info "Created $HOST_DIR/"
info "Files:"
ls -la "$HOST_DIR"

echo ""
info "Next steps:"
echo "  1. Edit $HOST_DIR/system.nix"
if [[ "$platform" == "nixos" && ("$host_type" == "bare-metal" || "$host_type" == "vm") ]]; then
    echo "  2. Generate hardware config: nixos-generate-config --show-hardware-config > $HOST_DIR/hardware.nix"
    echo "  3. Add SSH pubkey to secrets/pubkeys.nix (if secrets needed)"
fi
echo "  4. Validate: nix flake check"
echo "  5. Build: nix build .#${platform}Configurations.$hostname.config.system.build.toplevel"
