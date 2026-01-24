---
name: meta-verify-before-completion
description: Use when about to claim work is complete, before committing or reporting success. Requires running verification commands and confirming output before any success claims.
---

# Verify Before Completion

## Core Principle

**Evidence before assertions.** Never claim success without showing actual command output.

## When This Applies

- Before saying "done", "complete", "fixed", "working"
- Before committing changes
- Before reporting task completion to planner

## Required Verification

### For Nix Changes

```bash
# MUST run and show output:
nix fmt                    # Format check
nix flake check            # Full validation
nix build .#nixosConfigurations.<host>.config.system.build.toplevel  # Build test
```

### For Terraform Changes

```bash
nix run .#tfmgr -- validate
nix run .#tfmgr -- plan
```

### For Service Changes

```bash
# After deploy:
ssh <host> systemctl status <service>
ssh <host> systemctl --failed
```

## Anti-Patterns (NEVER Do)

| Bad | Why |
|-----|-----|
| "The build should pass now" | No evidence |
| "I fixed the error" | Didn't verify |
| "Changes are ready" | Didn't run checks |
| Committing without `nix fmt` | Formatting issues |

## Correct Pattern

```
1. Make changes
2. Run: nix fmt && nix flake check
3. Show actual output in response
4. THEN claim completion
```

## Report Format

When reporting completion, include:

```markdown
## Verification Results

**Commands run:**
- `nix fmt` ✅
- `nix flake check` ✅ 
- `nix build ...` ✅

**Output:**
[actual command output]

**Status:** Ready for review
```
