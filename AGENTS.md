# PROJECT KNOWLEDGE BASE

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix run .#tfmgr -- plan  # Terraform preview
```

## Rules

### NEVER
- Commit without user request
- Reference secrets directly (`"/run/agenix/..."`) — use `config.age.secrets.<name>.path`
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders
- Use `config.services.*` when `config.codgician.*` exists
- Claim "done" without verification output

### ALWAYS
- Run `nix fmt && nix flake check` before presenting changes
- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Show command output when claiming completion
- Request approval for: deploy, `tfmgr apply`, `agenix -r`

## Hosts

| Host | Platform | Type |
|------|----------|------|
| furina | aarch64-darwin | Mac (Apple Silicon) |
| raiden-ei | x86_64-darwin | Mac (Intel) |
| paimon | x86_64-linux | Primary server |
| fischl | x86_64-linux | Hypervisor |
| lumine | aarch64-linux | Azure VM |
| xianyun | x86_64-linux | Tencent VM |

## Key Patterns

- **Hosts**: `hosts/{darwin,nixos}/<name>/default.nix` using `lib.codgician.mk{Nixos,Darwin}System`
- **Services**: `modules/nixos/services/<name>/` with `codgician.services.<name>` namespace
- **Secrets**: `secrets/*.age` registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/` with Terranix syntax

## Commit Format

```
<scope>: <imperative verb> <description>
```
