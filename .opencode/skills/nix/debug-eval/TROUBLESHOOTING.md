# Troubleshooting: Debug Eval

> See AGENTS.md for global troubleshooting principles.

## Repo-Specific Error Patterns

### "attribute 'codgician' not found"

**Cause**: Not using `lib.codgician.mkNixosSystem` or `lib.codgician.mkDarwinSystem`

---

### "No such file: /etc/nixos/configuration.nix"

**Fix**: Remove all `/etc/nixos` paths from `hardware.nix`.

---

### "option used but not defined" for codgician.*

**Check locations**:
- NixOS modules: `modules/nixos/services/<name>/default.nix`
- Darwin modules: `modules/darwin/services/<name>/default.nix` (rare; only create when needed)

Auto-discovery uses `lib.codgician.getFolderPaths`.

---

### Overlay errors

**Repo pattern**: Overlays in `overlays/` apply 00-* first, 99-* last

**Debug**:
```bash
nix repl
:lf .
pkgs.x86_64-linux.myPackage
```

---

### Module options not visible

**Repo pattern**: All custom options under `codgician.*`:
- `codgician.services.<name>`
- `codgician.system.agenix`
- `codgician.system.impermanence`

---

## REPL Techniques

```nix
:lf .
nixosConfigurations.paimon.config.codgician.services.<name>.enable
nixosConfigurations.paimon.config ? codgician
nixosConfigurations.paimon.options.codgician.services.<name>.enable.definitionsWithLocations
```

---

## Finding Error Location

Focus on repo paths:
```bash
nix build ... --show-trace 2>&1 | grep "serenitea-pot"
```

---

## Performance Issues

**Slow evaluation**: Check for large IFD in overlays

**Out of memory**: `NIX_CONFIG="max-jobs = 1" nix build ...`
