# Troubleshooting: Build and Deploy

## Error: "connection refused" during remote deploy

**Causes**:
1. Host not reachable
2. SSH not running
3. Key not authorized

**Fix**:
```bash
ssh <host> echo "OK"
ping <host>
dig <host>
```

---

## Error: Build fails on remote

**Cause**: Building on remote but missing deps

**Fix**: Build locally, push closure:
```bash
nixos-rebuild switch --flake .#<host> \
  --target-host <host> \
  --build-host localhost \
  --use-remote-sudo
```

---

## Error: "out of disk space"

**Cause**: Nix store full

**Fix**:
```bash
ssh <host> sudo nix-collect-garbage -d

# Or keep last 5 generations
ssh <host> sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system
ssh <host> sudo nix-collect-garbage
```

---

## Services fail after deploy

**Diagnose**:
```bash
ssh <host> systemctl --failed
ssh <host> journalctl -u <service> -n 50
ssh <host> journalctl -xb
```

**Rollback if critical**:
```bash
ssh <host> sudo nixos-rebuild switch --rollback
```

---

## Locked out (can't SSH)

**Prevention**: Test SSH changes on non-critical host first.

**Recovery**:
1. Console access (IPMI, VM console, physical)
2. Boot previous generation from bootloader
3. Rescue boot with NixOS installer USB

---

## Darwin: "could not find any previously installed nix-darwin"

**Cause**: First-time or broken state

**Fix**:
```bash
nix build .#darwinConfigurations.<host>.system
./result/sw/bin/darwin-rebuild switch --flake .
```

---

## Slow deployment

**Causes**:
1. Large closure
2. Slow network
3. Building on remote

**Fix**:
```bash
# Build locally first
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# Use local build
nixos-rebuild switch --flake .#<host> --target-host <host> --build-host localhost --use-remote-sudo
```

---

## Generation not appearing

**Cause**: `test` command doesn't create generation

**Note**: `nixos-rebuild test` doesn't add generation, `switch` and `boot` do.

---

## Cross-architecture builds

For aarch64 on x86_64:
```nix
# Enable in config
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

Or use remote builder:
```bash
nix build .#nixosConfigurations.lumine... --builders "ssh://aarch64-builder"
```
