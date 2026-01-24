# Troubleshooting: Add NixOS Host

> See AGENTS.md for global troubleshooting principles.

## "attribute 'codgician' not found"

**Cause**: Module not using `lib.codgician.mkNixosSystem`

**Fix**: Ensure `default.nix` calls the builder:
```nix
lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  # ...
}
```

---

## "No such file: /etc/nixos/configuration.nix"

**Cause**: Hardware config references `/etc/nixos`

**Fix**: Remove all `/etc/nixos` paths from `hardware.nix`. This flake doesn't use `/etc/nixos`.

---

## Disko "Device busy"

**Cause**: Disk is mounted or in use

**Diagnosis**:
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS
findmnt | grep <disk>
```

**Safe steps**: `umount -R /mnt && partprobe`

**Destructive** (`wipefs`): Requires explicit user approval after confirming correct disk. See AGENTS.md principles.

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

## "infinite recursion encountered"

**Cause**: Module option conflict or self-reference

See [debug-eval](../skill-debug-eval/SKILL.md) for diagnosis.

---

## Boot fails after Disko

**Causes**: Wrong bootloader, missing initrd modules, wrong disk device

**Safe recovery**: Boot installer USB → mount → inspect. Or select previous generation from bootloader.

**Prevention**: Always test Disko config in VM first.

---

## Secret/agenix errors

See [manage-agenix/TROUBLESHOOTING.md](../skill-manage-agenix/TROUBLESHOOTING.md)

## Build/deploy errors

See [build-deploy/TROUBLESHOOTING.md](../skill-build-deploy/TROUBLESHOOTING.md)
