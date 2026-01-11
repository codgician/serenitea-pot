---
name: debug-eval
description: Diagnose and fix Nix evaluation errors, build failures, and module conflicts.
tags: [nixos, debug, eval, build, error]
when_to_use: Build fails, eval errors, infinite recursion, attribute not found
blast_radius: LOW
---

# Debug Nix Eval/Build Failure

## Quick Start

```bash
# Get error trace
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --show-trace 2>&1 | head -100

# Interactive debugging
nix develop .#repl
```

## Common Errors

| Error | Likely Cause |
|-------|--------------|
| `attribute 'X' missing` | Typo, missing import, wrong path |
| `infinite recursion` | Self-referential option, circular mkIf |
| `expected X but got Y` | Wrong option type |
| `assertion failed` | Constraint violation |
| `builder failed` | Derivation build error |

---

# Diagnostic Commands

```bash
# Full trace
nix build ... --show-trace 2>&1 | head -200

# Save to file
nix build ... --show-trace 2>&1 > /tmp/nix-error.log

# REPL debugging
nix develop .#repl
# Then:
nixosConfigurations.<host>.config.services.nginx
nixosConfigurations.<host>.config ? codgician
```

---

# Error: "attribute 'X' missing"

## Cause 1: Module not imported

**Fix**: Ensure `default.nix` uses builder:
```nix
lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
}
```

## Cause 2: Typo

```nix
# Wrong
config.codgician.servces.jellyfin  # typo!

# Correct
config.codgician.services.jellyfin
```

## Cause 3: Wrong scope

```nix
# Wrong: config not available in options
options.myOption = lib.mkOption {
  default = config.other.option;  # ERROR
};

# Correct: use in config section
config = lib.mkIf cfg.enable {
  other.option = config.some.value;  # OK
};
```

---

# Error: "infinite recursion"

## Cause 1: Self-referential default

```nix
# Wrong
myOption = lib.mkOption {
  default = config.myOption;  # RECURSION
};
```

## Cause 2: Circular mkIf

```nix
# Problematic: A depends on B, B depends on A
config = lib.mkMerge [
  (lib.mkIf config.a.enable { b.enable = true; })
  (lib.mkIf config.b.enable { a.enable = true; })
];
```

## Debugging

Add trace:
```nix
config = lib.mkIf (builtins.trace "evaluating mymodule" cfg.enable) { };
```

---

# Error: Type mismatch

```nix
# Wrong
port = "8080";  # String

# Correct
port = 8080;    # Integer
```

Check option type in REPL:
```nix
nixosConfigurations.<host>.options.services.myservice.port
```

---

# Error: Assertion failed

**Cause**: Configuration violates constraint

**Fix**: Read message, enable required dependency:
```nix
# Error: "myservice requires postgresql"
services.postgresql.enable = true;
```

---

# Error: Build failure (derivation)

```bash
# Get build log
nix log /nix/store/XXX-mypackage.drv

# Rebuild with verbose
nix build .#mypackage -L
```

**Common causes**:
- Missing dependency in `buildInputs`
- Patch doesn't apply (source changed)
- Test failure (try `doCheck = false`)

---

# Debugging Techniques

## Binary Search (git bisect)
```bash
git bisect start
git bisect bad HEAD
git bisect good <working-commit>
# Test each: nix build ...
```

## Simplify Configuration
```nix
modules = [
  ./system.nix
  # ./problematic.nix  # Comment out
];
```

## Trace Evaluation
```nix
myValue = builtins.trace "myValue = ${toString myValue}" myValue;
myValue = lib.traceValSeq myValue;
```

## Check Dependencies
```bash
nix why-depends .#nixosConfigurations.<host>.config.system.build.toplevel /nix/store/XXX
```

---

# Quick Reference

| Error | Quick Fix |
|-------|-----------|
| `attribute 'codgician' missing` | Use `lib.codgician.mkNixosSystem` |
| `attribute 'X' missing` | Check typos, verify import |
| `infinite recursion` | Check defaults, circular mkIf |
| `expected string but got set` | Check option type |
| `assertion failed` | Enable required deps |
| `builder failed` | Check `nix log`, deps, tests |

---

# Exit Criteria

- [ ] Error understood
- [ ] Root cause identified
- [ ] Fix applied
- [ ] `nix flake check` passes
- [ ] `nix build` succeeds

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more patterns.

# Related Skills

- [build-deploy](../build-deploy/SKILL.md) — After fixing
- [add-service](../add-service/SKILL.md) — Service errors
