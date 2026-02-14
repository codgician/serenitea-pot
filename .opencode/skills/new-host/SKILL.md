---
name: new-host
description: Add a new NixOS or Darwin host to serenitea-pot. Use when user asks to add a machine, create a host, or bootstrap a new system.
---

# Add New Host

## Step 1: Gather Requirements

Ask the user:

| Question | Options |
|----------|---------|
| **Platform** | `nixos` or `darwin` |
| **Hostname** | Genshin character (lowercase, e.g., `nahida`, `furina`) |
| **Architecture** | NixOS: `x86_64-linux`, `aarch64-linux` / Darwin: `aarch64-darwin`, `x86_64-darwin` |
| **Type** (NixOS only) | `bare-metal`, `vm`, `container`, `wsl` |

## Step 2: Run Bootstrap Script

```bash
./new-host.sh <platform> <hostname> <arch> [type]
```

**Examples:**
```bash
./new-host.sh nixos wanderer x86_64-linux wsl
./new-host.sh darwin keqing aarch64-darwin
```

## Step 3: Customize Configuration

Edit `hosts/<platform>/<hostname>/system.nix`:

### NixOS Specifics
- **Bare metal/VM**: Generate hardware config with `nixos-generate-config --show-hardware-config`
- **Secrets access**: Add SSH pubkey to `secrets/pubkeys.nix`, then `agenix -r`
- **Impermanence**: Set `codgician.system.impermanence.enable = true`

### Darwin Specifics
- **Homebrew casks**: Add to `codgician.system.brew.casks`
- **App Store apps**: Find IDs with `mas search "App Name"`, add to `masApps`

## Step 4: Validate & Build

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel  # NixOS
nix build .#darwinConfigurations.<hostname>.system                        # Darwin
```

## Step 5: Deploy (User Approval Required)

### NixOS
```bash
nixos-rebuild switch --flake .#<hostname> --target-host <hostname> --use-remote-sudo
```

### Darwin (first time)
```bash
./result/sw/bin/darwin-rebuild switch --flake .
```

## Exit Criteria

- [ ] Host directory exists at `hosts/<platform>/<hostname>/`
- [ ] `nix flake check` passes
- [ ] Build succeeds
