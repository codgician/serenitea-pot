---
name: skill-add-nixos-host
description: Bootstrap a new NixOS host in the serenitea-pot flake.
tags: [nixos, host, bootstrap]
when_to_use: User asks to add host, create new machine, or bootstrap NixOS system
blast_radius: CRITICAL
---

# Add NixOS Host

Load `fact-nix` for system builders and host reference.

## Required Inputs

- [ ] **Host name** (Genshin character)
- [ ] **Architecture** (`x86_64-linux` or `aarch64-linux`)
- [ ] **Type**: bare-metal / VM / container / WSL
- [ ] **Impermanence?** (stateless root)

## Naming Convention

| Type | Name After | Example |
|------|------------|---------|
| Bare metal | Human characters | paimon, fischl |
| VM/Container | Archons | focalors, nahida |
| WSL | Male characters | wanderer |

## Procedure

### 1. Create Host Directory

```bash
mkdir -p hosts/nixos/<hostname>
```

### 2. Create default.nix

```nix
{ lib, ... }:
lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-linux";
  modules = [ ./system.nix ];
}
```

### 3. Create system.nix

```nix
{ config, lib, pkgs, ... }:
{
  codgician = {
    system.common.enable = true;
    users.codgi.enable = true;
  };
  system.stateVersion = "25.11";
}
```

**Type-specific:**
- Bare metal: add `./hardware.nix`, `./disks.nix`
- Container: add `boot.isContainer = true;`
- WSL: add `codgician.system.wsl.enable = true;`

### 4. Register Host Key

```bash
# Get key from target
cat /etc/ssh/ssh_host_ed25519_key.pub

# Add to secrets/pubkeys.nix under hosts = { ... }
# Then rekey (requires user approval):
agenix -r
```

### 5. Validate

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### 6. Deploy (User Approval Required)

```bash
# Remote
nixos-rebuild switch --flake .#<hostname> --target-host <hostname> --use-remote-sudo

# Fresh install with Disko (DESTRUCTIVE - verify disk first!)
lsblk -o NAME,SIZE,MODEL,SERIAL
nix run github:nix-community/disko -- --mode disko ./disks.nix
nixos-install --flake .#<hostname>
```

## Exit Criteria

- [ ] Host directory exists with `default.nix`, `system.nix`
- [ ] Host pubkey in `secrets/pubkeys.nix`
- [ ] `nix flake check` passes
- [ ] Deploy succeeds, `systemctl --failed` empty

**Reference**: See `hosts/nixos/paimon/` (bare metal), `hosts/nixos/wanderer/` (WSL), `hosts/nixos/nahida/` (container).

**Note**: Do not commit — present changes to user.
