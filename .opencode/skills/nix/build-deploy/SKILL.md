---
name: build-deploy
description: Build and deploy NixOS or Darwin configurations to local or remote hosts.
tags: [nixos, darwin, deploy, build]
when_to_use: User needs to build, deploy, or update a host
blast_radius: MEDIUM
---

# Build and Deploy

## Quick Start

```bash
# NixOS local
sudo nixos-rebuild switch --flake .#<host>

# NixOS remote
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo

# Darwin local
darwin-rebuild switch --flake .#<host>
```

## Safety Rules

- ⚠️ **VERIFY** target hostname before deploying
- ⚠️ **BUILD** before deploying to catch errors
- ⚠️ **TEST** major changes in VM first
- ❌ **NEVER** deploy to production without building first

---

# Build Commands

```bash
# Build without deploying
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#darwinConfigurations.<host>.system

# Check all configs (eval only)
nix flake check

# Build VM for testing
nixos-rebuild build-vm --flake .#<host>
./result/bin/run-<host>-vm
```

---

# Deploy Commands

## NixOS

```bash
# Local
sudo nixos-rebuild switch --flake .#<host>   # Apply now
sudo nixos-rebuild boot --flake .#<host>     # Apply on reboot
sudo nixos-rebuild test --flake .#<host>     # Test (reverts on reboot)

# Remote
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo
```

## Darwin

```bash
darwin-rebuild switch --flake .#<host>

# Bootstrap (first time)
nix build .#darwinConfigurations.<host>.system
./result/sw/bin/darwin-rebuild switch --flake .
```

---

# Host Reference

| Host | Type | Deploy Command |
|------|------|----------------|
| furina | Darwin | `darwin-rebuild switch --flake .#furina` |
| raiden-ei | Darwin | `darwin-rebuild switch --flake .#raiden-ei` |
| paimon | NixOS | `--target-host paimon` |
| fischl | NixOS | `--target-host fischl` |
| sandrone | NixOS | `--target-host sandrone` |
| focalors | NixOS | VM in Parallels |
| nahida | NixOS | LXC Container |
| lumine | NixOS | Cloud VM |
| xianyun | NixOS | Cloud VM |
| wanderer | NixOS | WSL |

---

# Procedure: Safe Deployment

## Phase 1: Build

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix flake check
```

## Phase 2: Review (Optional)

```bash
nixos-rebuild dry-run --flake .#<host>
```

## Phase 3: Deploy

```bash
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo
```

## Phase 4: Verify

```bash
ssh <host> systemctl --failed
ssh <host> systemctl status <service>
ssh <host> nixos-rebuild list-generations | head -5
```

---

# Rollback

```bash
# Immediate rollback
ssh <host> sudo nixos-rebuild switch --rollback

# List generations
ssh <host> nixos-rebuild list-generations

# Specific generation
ssh <host> sudo nix-env --switch-generation <N> -p /nix/var/nix/profiles/system
ssh <host> sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

# Exit Criteria

- [ ] Configuration builds
- [ ] Deployment completes
- [ ] `systemctl --failed` empty
- [ ] Critical services running
- [ ] SSH access works

---

# Commit (User Approval Required)

If config changes were made before deploying:

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- hosts/nixos/<host>/system.nix (modified)

Proposed: `<host>: <brief description>`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [add-nixos-host](../add-nixos-host/SKILL.md) — New hosts
- [add-darwin-host](../add-darwin-host/SKILL.md) — macOS hosts
- [debug-eval](../debug-eval/SKILL.md) — Build errors
