---
name: skill-debug-eval
description: Diagnose and fix Nix evaluation errors, build failures, and module conflicts.
tags: [nixos, debug, eval, build, error]
when_to_use: Build fails, eval errors, infinite recursion, attribute not found
blast_radius: LOW
---

# Debug Nix Eval/Build Failure

Load `fact-nix` for module patterns if needed.

## Quick Start

```bash
# Capture full trace (don't lose root cause)
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --show-trace 2>&1 | tee /tmp/nix-error.log

# Find repo-specific lines
grep "serenitea-pot" /tmp/nix-error.log

# Interactive debugging
nix develop .#repl
```

## Common Errors

| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `attribute 'X' missing` | Typo, missing import | Check spelling, verify module loaded |
| `attribute 'codgician' missing` | Wrong builder | Use `lib.codgician.mkNixosSystem` |
| `infinite recursion` | Self-referential option | Check defaults, circular `mkIf` |
| `expected X but got Y` | Wrong option type | Check type in REPL |
| `assertion failed` | Constraint violation | Enable required dependency |
| `builder failed` | Derivation error | Check `nix log`, deps, tests |

## Debugging Patterns

### Attribute Missing

```nix
# Wrong scope (config not available in options)
options.myOption = lib.mkOption {
  default = config.other.option;  # ERROR
};

# Correct: use in config section
config = lib.mkIf cfg.enable {
  value = config.some.option;  # OK
};
```

### Infinite Recursion

```nix
# Self-referential default
myOption = lib.mkOption {
  default = config.myOption;  # RECURSION
};

# Circular mkIf
(lib.mkIf config.a.enable { b.enable = true; })
(lib.mkIf config.b.enable { a.enable = true; })  # RECURSION
```

### Add Traces

```nix
config = lib.mkIf (builtins.trace "evaluating mymodule" cfg.enable) { };
myValue = lib.traceValSeq myValue;
```

## Diagnostic Commands

```bash
# REPL inspection
nix develop .#repl
# Then: nixosConfigurations.<host>.config.services.nginx
# Then: nixosConfigurations.<host>.config ? codgician

# Build log for derivation failures
nix log /nix/store/XXX-mypackage.drv

# Binary search with git bisect
git bisect start && git bisect bad HEAD && git bisect good <working>
```

## Exit Criteria

- [ ] Error message understood
- [ ] Root cause identified (not just symptom)
- [ ] Fix applied
- [ ] `nix flake check` passes
- [ ] `nix build` succeeds

**Note**: Do not commit — present fix to user.
