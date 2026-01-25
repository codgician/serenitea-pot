# Troubleshooting: Build and Deploy

> See AGENTS.md for global troubleshooting principles.

## "connection refused" during remote deploy

| Failure Type | Action |
|--------------|--------|
| Network unreachable | Report to user |
| SSH auth failure | **Ask user** to resolve keys/access |
| SSH not running | May need console access |

---

## Build fails on remote

**Safe alternative** (validate without deploying):
```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Deployment requires user approval per AGENTS.md principles.

---

## "out of disk space"

**Safe option** (keeps recent generations):
```bash
ssh <host> sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system
ssh <host> sudo nix-collect-garbage
```

`nix-collect-garbage -d` removes ALL generations - requires user approval.

---

## Services fail after deploy

**Diagnosis**: `ssh <host> systemctl --failed`

Rollback (`nixos-rebuild switch --rollback`) requires user approval.

---

## Locked out (can't SSH)

**This requires user intervention.** Recovery options:
1. Console access (IPMI, VM console, physical)
2. Boot previous generation from bootloader
3. Rescue boot with NixOS installer USB

---

## Darwin: "could not find any previously installed nix-darwin"

**Fix**:
```bash
nix build .#darwinConfigurations.<host>.system
./result/sw/bin/darwin-rebuild switch --flake .
```

---

## Slow deployment

**Fix**: Build locally first:
```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Then deploy with `--build-host localhost`.

---

## Cross-architecture builds

For aarch64 on x86_64:
```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```
