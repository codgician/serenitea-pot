---
name: add-nixos-host
description: Bootstrap a new NixOS host in the serenitea-pot flake.
tags: [nixos, host, bootstrap, disko, impermanence]
when_to_use: User asks to add host, create new machine, or bootstrap NixOS system
blast_radius: CRITICAL
---

# Add NixOS Host

## Quick Start

Create host at `hosts/nixos/<name>/` using `lib.codgician.mkNixosSystem`.

## Required Inputs

- [ ] **Host name** (Genshin character - see naming rules)
- [ ] **System architecture** (`x86_64-linux` or `aarch64-linux`)
- [ ] **Host type**: bare-metal / VM / container / WSL
- [ ] **Impermanence?** (stateless root)
- [ ] **Secure boot?** (bare metal with UEFI)
- [ ] **Disk layout** (for Disko, if applicable)

## Naming Rules

| Host Type | Name After | Examples |
|-----------|------------|----------|
| Bare metal | Human characters | fischl, paimon |
| VMs/Containers | Archons/Dragons | focalors, nahida |
| aarch64 | Fontaine/Descenders | lumine |
| WSL | Male characters | wanderer |

## Safety Rules

- ⚠️ **ALWAYS** test Disko config in VM before bare metal
- ⚠️ **ALWAYS** add host pubkey to `secrets/pubkeys.nix` before deploying
- ❌ **NEVER** run Disko without verifying target disk device
- ❌ **NEVER** forget impermanence identity paths

---

# Procedure

## Phase 1: Create Directory

```bash
mkdir -p hosts/nixos/<hostname>
```

## Phase 2: Create Files

### default.nix (Required)

```nix
{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-linux";  # or aarch64-linux
  modules = [
    ./system.nix
    # ./hardware.nix  # Bare metal / VM
    # ./disks.nix     # If using Disko
  ];
}
```

### system.nix (Required)

```nix
{ config, lib, pkgs, ... }:

{
  codgician = {
    system.common.enable = true;
    users.codgi.enable = true;
  };

  environment.systemPackages = with pkgs; [ vim git htop ];

  system.stateVersion = "25.11";
}
```

### Host Type Specifics

| Type | Files Needed | Notes |
|------|--------------|-------|
| Bare metal | default, system, hardware, disks | Full setup |
| VM | default, system, hardware, disks | Simpler hardware config |
| Container (LXC) | default, system | No boot/disko |
| WSL | default, system | Uses nixos-wsl module |

## Phase 3: Register Host Key

**Critical**: Without this, secrets won't decrypt.

1. Get host SSH public key:
   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Add to `secrets/pubkeys.nix`:
   ```nix
   hosts = {
     <hostname> = [ "ssh-ed25519 AAAA..." ];
   };
   ```

3. Rekey secrets (requires user approval):
   
   ⚠️ **STOP**: Ask user before rekeying.
   ```bash
   agenix -r
   ```

## Phase 4: Impermanence (If Enabled)

```nix
codgician.system.impermanence = {
  enable = true;
  path = "/persist";
};
```

Ensure host key persists at `/persist/etc/ssh/ssh_host_ed25519_key`.

## Phase 5: Validate

```bash
nix flake check
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

## Phase 6: Deploy (User Approval Required)

⚠️ **STOP**: Deployment changes system state. Ask user before proceeding.

```bash
# Local
sudo nixos-rebuild switch --flake .#<hostname>

# Remote
nixos-rebuild switch --flake .#<hostname> --target-host <hostname> --use-remote-sudo
```

### Fresh Install with Disko (DESTRUCTIVE)

⚠️ **STOP**: Disko DESTROYS all data on target disk. Requires explicit user approval.

**Mandatory verification before Disko**:
```bash
# Verify correct disk - check SIZE, MODEL, SERIAL
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS

# Use /dev/disk/by-id/ paths for safety
ls -la /dev/disk/by-id/
```

After user confirms correct disk:
```bash
nix run github:nix-community/disko -- --mode disko /path/to/disks.nix
nixos-install --flake .#<hostname>
```

## Phase 7: Verify

```bash
ssh <hostname> systemctl --failed
ssh <hostname> ls -la /run/agenix/  # Secrets decrypt
```

---

# Examples

## WSL Host (Minimal)

```
hosts/nixos/wanderer/
├── default.nix
└── system.nix
```

**system.nix** with WSL:
```nix
{ config, lib, pkgs, ... }:

{
  codgician = {
    system.common.enable = true;
    system.wsl = {
      enable = true;
      defaultUser = "codgi";
    };
    users.codgi.enable = true;
  };
  system.stateVersion = "25.11";
}
```

## LXC Container

**system.nix** for container:
```nix
{ config, lib, pkgs, ... }:

{
  codgician = {
    system.common.enable = true;
    users.codgi.enable = true;
  };
  boot.isContainer = true;  # No bootloader
  system.stateVersion = "25.11";
}
```

## Disko (Simple Single Disk)

```nix
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";  # VERIFY THIS!
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
        };
        root = {
          size = "100%";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
      };
    };
  };
}
```

## Reference Hosts

| Type | Host | See |
|------|------|-----|
| Bare metal | paimon | `hosts/nixos/paimon/` |
| VM | focalors | `hosts/nixos/focalors/` |
| Container | nahida | `hosts/nixos/nahida/` |
| WSL | wanderer | `hosts/nixos/wanderer/` |

---

# Exit Criteria

- [ ] Host directory: `hosts/nixos/<hostname>/`
- [ ] Files: `default.nix`, `system.nix` (+ hardware/disks if needed)
- [ ] Host pubkey in `secrets/pubkeys.nix`
- [ ] `nix build` succeeds
- [ ] Deploy succeeds
- [ ] SSH works
- [ ] Secrets decrypt (if applicable)
- [ ] `systemctl --failed` is empty

---

# Commit (User Approval Required)

First, format all code:
```bash
nix fmt
```

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- hosts/nixos/<hostname>/ (new)
- secrets/pubkeys.nix (modified)

Proposed: `<hostname>: init nixos host`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [add-darwin-host](../add-darwin-host/SKILL.md) — macOS hosts
- [manage-agenix](../../secrets/manage-agenix/SKILL.md) — Secret management
- [build-deploy](../build-deploy/SKILL.md) — Deployment
- [debug-eval](../debug-eval/SKILL.md) — Build errors
