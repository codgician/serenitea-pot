---
name: skill-build-deploy
description: Build and deploy NixOS or Darwin configurations to local or remote hosts.
tags: [nixos, darwin, deploy, build]
when_to_use: User needs to build, deploy, or update a host
blast_radius: MEDIUM
---

# Build and Deploy

## Required Inputs

- [ ] **Host name**
- [ ] **Type** (NixOS or Darwin)
- [ ] **Local or remote?**

## Safety Rules

- ⚠️ **BUILD** before deploying to catch errors
- ⚠️ **VERIFY** target hostname before deploying
- ⚠️ **TEST** major changes in VM first
- ❌ **NEVER** run deploy commands without user approval

## Procedure

### 1. Build (Safe)

```bash
# NixOS
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# Darwin
nix build .#darwinConfigurations.<host>.system

# Check all configs
nix flake check
```

### 2. Deploy (User Approval Required)

⚠️ **STOP**: Ask user before running any deploy command.

```bash
# NixOS local
sudo nixos-rebuild switch --flake .#<host>

# NixOS remote
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo

# Darwin
darwin-rebuild switch --flake .#<host>
```

### 3. Verify

```bash
ssh <host> systemctl --failed
ssh <host> systemctl status <service>
```

## Host Reference

| Host | Type | Notes |
|------|------|-------|
| furina, raiden-ei | Darwin | `darwin-rebuild switch` |
| paimon, fischl, sandrone | NixOS | `--target-host` |
| focalors | NixOS | VM in Parallels |
| nahida | NixOS | LXC Container |
| lumine, xianyun | NixOS | Cloud VM |
| wanderer | NixOS | WSL |

## Rollback (User Approval Required)

```bash
# Immediate rollback
ssh <host> sudo nixos-rebuild switch --rollback

# Specific generation
ssh <host> nixos-rebuild list-generations
ssh <host> sudo nix-env --switch-generation <N> -p /nix/var/nix/profiles/system
```

## Exit Criteria

- [ ] Configuration builds successfully
- [ ] Code formatted (`nix fmt`)
- [ ] Deployment completes (if approved)
- [ ] `systemctl --failed` empty
- [ ] SSH access works

**Note**: Do not commit — present changes to user.
