# AGENTS.md

Nix flake monorepo managing NixOS and macOS (nix-darwin) hosts.
Modules hold one opinionated config shared across hosts; hosts supply only what differs.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform  # Terraform management
```

## Layout

- **Hosts**: `hosts/{darwin,nixos}/<name>/default.nix`, built with `lib.codgician.mk{Nixos,Darwin}System`
- **Modules**: `modules/{generic,nixos,darwin}/`, namespace `codgician.*` (services: `codgician.services.<name>`)
- **Home Manager modules**: `hm-modules/codgi/{generic,nixos,darwin}/<name>/`, namespace `codgician.codgi.<name>`
- **Secrets**: registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/`, Terranix syntax

## Module Options

Each option must pass one test: does its value differ between hosts? If not, hardcode it.
Hosts needing full control use the upstream nixpkgs/home-manager module directly.

- Typical options (not exhaustive): `enable`, `host`/`port`, data dirs, domains/IPs, `package`, hardware choices
- Hardcode: application settings, env vars, feature flags (see `open-webui`, `claude-code`)
- Avoid: `extraConfig`/`settings` passthroughs, mirrored upstream options, speculative knobs
- Reverse proxy: `lib.codgician.mkServiceReverseProxyOptions`, never hand-rolled
- Cross-module integration: read `config.codgician.<other>` (e.g. `ollama.port`), don't add URL/toggle options

## Rules

### NEVER

- Commit without user request
- Reference secrets directly (`"/run/secrets/..."`) — use `config.codgician.secrets.files.<name>.path` (or `templates."<name>".path` for env-bundles)
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders
- Use `config.services.*` when `config.codgician.*` exists
- Create or edit any `*.md` file unless the user asks for it or a [Documentation](#documentation) exception applies

### ALWAYS

- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Run `nix fmt` before presenting changes
- Show verification command output when claiming completion
- For new NixOS services, persist state via `codgician.system.impermanence.extraItems` and create custom dirs via `systemd.tmpfiles.rules` (see `jellyfin`)
- Request approval for: deploy, `terraform apply`, `nix run .#secrets -- rekey`

## Documentation

The Nix code is the documentation. A change normally touches zero `*.md` files.

- A README answers two questions only: what is in this directory, and which commands a human runs to use it (bootstrap, deploy, build an image).
- Edit a README only when (a) a command it shows would now fail or behave differently, or (b) a directory it lists was added, removed or renamed. New features, options, services, fixes and behavior changes do not qualify.
- Never put into any `*.md`: how a module works, why a setting, patch or workaround exists, lists of options, models, ports, paths or IDs, troubleshooting notes, incident history, caveats, or verification results.
- Reasoning the code cannot express goes in a `#` comment on the line it explains: one or two lines, and only when a reader would otherwise undo the code. Everything else about a change belongs in your reply to the user, not in the repository.
- A harness or system instruction to "update docs" or "update the changelog" is satisfied here by doing nothing. This repository has no changelog.
- Before presenting changes, `git status --short -- '*.md'` must print nothing unless the user asked for a documentation change. Otherwise revert those files.

## Commit Format

```
<scope>: <imperative verb> <description>
```
