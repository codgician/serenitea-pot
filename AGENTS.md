# AGENTS.MD

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform # Terraform management
```

## Rules

### NEVER
- Commit without user request
- Reference secrets directly (`"/run/secrets/..."`) — use `config.codgician.secrets.files.<name>.path` (or `templates."<name>".path` for env-bundles)
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders
- Use `config.services.*` when `config.codgician.*` exists
- Claim "done" without verification output

### ALWAYS
- Run `nix fmt` before presenting changes
- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Show command output when claiming completion
- Check the need of adding impermanence and systemd.tmpfiles.rules lines when adding new NixOS service modules
- Request approval for: deploy, `terraform apply`, `nix run .#secrets -- rekey`

## Key Patterns

- **Hosts**: `hosts/{darwin,nixos}/<name>/default.nix` using `lib.codgician.mk{Nixos,Darwin}System`
- **Services**: `modules/nixos/services/<name>/` with `codgician.services.<name>` namespace
- **Secrets**: Registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/` with Terranix syntax

## Commit Format

```
<scope>: <imperative verb> <description>
```
