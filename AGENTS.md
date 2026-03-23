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
- Run `nix fmt` before presenting changes
- Run `nix flake check` to validate changes. If the user ask you to switch to new config, you can run nixos-rebuild directly instead.
- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Show command output when claiming completion
- Check the need of adding impermanence and systemd.tmpfiles.rules lines when adding new NixOS service modules
- Request approval for: deploy, `tfmgr apply`, `agenix -r`

## Key Patterns

- **Hosts**: `hosts/{darwin,nixos}/<name>/default.nix` using `lib.codgician.mk{Nixos,Darwin}System`
- **Services**: `modules/nixos/services/<name>/` with `codgician.services.<name>` namespace
- **Secrets**: `secrets/*.age` registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/` with Terranix syntax

## Commit Format

```
<scope>: <imperative verb> <description>
```
