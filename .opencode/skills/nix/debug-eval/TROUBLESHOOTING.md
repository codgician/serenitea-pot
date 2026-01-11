# Troubleshooting: Debug Eval

## Extended Error Patterns

### "No such file: /etc/nixos/configuration.nix"

**Cause**: Hardware config references old path

**Fix**: Remove all `/etc/nixos` paths from `hardware.nix`

---

### "option used but not defined"

**Cause**: Using option that doesn't exist

**Debug**:
```bash
nix repl
:lf .
nixosConfigurations.<host>.options.path.to.option
# error means option doesn't exist
```

---

### "value is a function while a set was expected"

**Cause**: Missing function argument

```nix
# Wrong
{ config, lib, ... }: config.something

# Right (in module)
{ config, lib, ... }: {
  # module content
}
```

---

### "cannot coerce a set to a string"

**Cause**: Trying to interpolate attrset

```nix
# Wrong
"${someAttrset}"

# Right
"${someAttrset.specificAttr}"
# or
builtins.toJSON someAttrset
```

---

### Overlay errors

**Check order**: Overlays apply 00-* first, 99-* last

**Debug**:
```bash
nix repl
:lf .
pkgs = import nixpkgs { overlays = [...]; }
pkgs.myPackage
```

---

### "path does not exist"

**Cause**: Relative path wrong or file missing

```nix
# Wrong (relative to wrong dir)
./../../some/file.nix

# Check with
builtins.pathExists ./path/to/file.nix
```

---

### Module load order issues

**Symptom**: Option defined in one module not visible in another

**Fix**: Use `imports` correctly or define option with `lib.mkOption`

---

### "called with unexpected argument"

**Cause**: Function signature mismatch

```nix
# Module expects
{ config, lib, pkgs, ... }:

# Called with extra arg
{ config, lib, pkgs, unexpectedArg, ... }:  # ERROR
```

---

## REPL Techniques

```nix
# Load flake
:lf .

# Check config
nixosConfigurations.paimon.config.services.nginx.enable

# Check if attribute exists
nixosConfigurations.paimon.config ? codgician

# Get option definition location
nixosConfigurations.paimon.options.services.nginx.enable.definitionsWithLocations

# Evaluate with trace
:p builtins.trace "debug" someValue

# Check type
builtins.typeOf someValue
```

---

## Performance Issues

### Slow evaluation

**Causes**:
1. Large IFD (import from derivation)
2. Recursive overlays
3. Excessive `lib.recursiveUpdate`

**Debug**:
```bash
time nix eval .#nixosConfigurations.<host>.config.system.build.toplevel
```

### Out of memory

**Fix**:
```bash
# Increase memory
NIX_CONFIG="max-jobs = 1" nix build ...
```

---

## Finding Error Location

```bash
# Get line numbers
nix build ... --show-trace 2>&1 | grep -E "at /|error:"

# Filter to your files only
nix build ... --show-trace 2>&1 | grep -E "serenitea-pot"
```
