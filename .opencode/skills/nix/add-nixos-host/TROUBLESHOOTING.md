# Troubleshooting: Add NixOS Host

## Error: "attribute 'codgician' not found"

**Cause**: Module not using `lib.codgician.mkNixosSystem`

**Fix**: Ensure `default.nix` calls the builder:
```nix
lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  # ...
}
```

See [debug-eval](../debug-eval/SKILL.md) for detailed diagnosis.

---

## Error: "No such file: /etc/nixos/configuration.nix"

**Cause**: Hardware config references `/etc/nixos`

**Fix**: Remove all `/etc/nixos` paths from `hardware.nix`. This flake doesn't use `/etc/nixos`.

---

## Error: "Permission denied" on secrets at runtime

**Cause**: Host not in `secrets/pubkeys.nix`

**Fix**:
```bash
# 1. Add host key to secrets/pubkeys.nix
# 2. Rekey all secrets
agenix -r
# 3. Rebuild
```

---

## Error: Disko "Device busy"

**Cause**: Disk is mounted or in use

**Fix**:
```bash
# Unmount all partitions
umount -R /mnt

# Verify correct disk (CRITICAL - check SIZE, MODEL, SERIAL)
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS

# Use /dev/disk/by-id/ for safety
ls -la /dev/disk/by-id/

# Clear partition table (DANGEROUS!)
wipefs -a /dev/disk/by-id/<disk-id>

# Run partprobe
partprobe

# Retry disko
```

---

## Secrets don't decrypt after reboot (impermanence)

**Cause**: Host identity key not in persistent storage

**Fix**: Ensure host key persists:
```nix
codgician.system.impermanence.extraItems = [
  { path = "/etc/ssh/ssh_host_ed25519_key"; type = "file"; mode = "0600"; }
  { path = "/etc/ssh/ssh_host_ed25519_key.pub"; type = "file"; mode = "0644"; }
];
```

---

## Build fails: "infinite recursion encountered"

**Cause**: Module option conflict or self-reference

**Fix**: See [debug-eval](../debug-eval/SKILL.md) for diagnosis techniques.

---

## Error: "connection refused" during remote deploy

**Causes**:
1. Host not reachable (network)
2. SSH not running
3. SSH key not authorized

**Fix**:
```bash
# Test connectivity
ping <hostname>
ssh <hostname> echo "OK"

# Check DNS
dig <hostname>
```

---

## Error: Boot fails after Disko

**Causes**:
1. Wrong bootloader config
2. Missing kernel modules in initrd
3. Wrong disk device in config

**Recovery**:
1. Boot from NixOS installer USB
2. Mount partitions manually
3. Check `/mnt/etc/nixos/` (if copied) or re-run `nixos-install`

**Prevention**: Always test Disko config in VM first.
