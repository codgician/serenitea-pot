# AGENTS.md

Nix flake managing NixOS and macOS (nix-darwin) hosts.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform  # Terraform management
```

## Layout

- `hosts/{nixos,darwin}/<name>/`: one folder per host. `default.nix` is its manifest `{ system; cudaSupport ? false; stable ? true; modules = [ … ]; }`; the order of `modules` decides how lists merge, so keep it
- `modules/{generic,nixos,darwin}/`: modules under `codgician.*`, loaded on every host of their class
- `hm-modules/codgi/{generic,nixos,darwin}/<name>/`: Home Manager modules under `codgician.codgi.<name>`
- `overlays/`, `lib/` (`lib.codgician.zone` is the DNS zone), `secrets/secrets.nix`, `packages/terraform-config/` (Terranix), `tests/` (`checks.<system>.*`)

**Before you edit anything under `modules/`, `hm-modules/` or `overlays/`, or publish or move a service, read `modules/AGENTS.md`.**

## Principles

1. **A value lives next to what decides it.** Ask what would make it change.
   - The software, or the fixed way this fleet runs it: its module (port, public name, who may access it, its database).
   - The machine, at install time or because of its hardware: that host's files (disks, ESP, pools, boot loader, RAID, firmware, TPM, kernel).
   - A decision about one machine: that host's files (what it runs, where its data lives, taste).
   - The fleet as a whole: `lib/consts.nix`, nothing else.
2. **Being read elsewhere is no reason to move a value.** Every module is loaded on every host, so what a module declares is already visible everywhere.
3. **A relation between two machines is configured on the machine that acts.** "lumine proxies jellyfin to paimon" is lumine's configuration.
4. **A table of facts belongs to the module that consumes it**, and is filled next to the code each fact is about.
5. **Duplication is allowed.** There are no roles, profiles or files shared between hosts; editing one host must never change another. When in doubt, duplicate.

What a host runs: the `enable` lines in its files. No host evaluates another; the one exception is `hosts/nixos/paimon/lab.nix`, which uses nahida's system as a container root.

## Rules

### NEVER

- Commit without user request
- Reference secrets by path (`"/run/secrets/..."`); use `config.codgician.secrets.files.<name>.path` or `templates."<name>".path`
- Write raw `.tf` files, or `${...}` interpolation in Terranix (use `config.resource.X.Y "attr"`)
- Build a host other than through its folder and manifest under `hosts/`
- Add a table of facts no module owns, an option whose default depends on the host name, or a file shared between hosts
- Type the zone in new Nix code; use `lib.codgician.zone`
- Use `config.services.*` where `config.codgician.*` exists
- Create or edit any `*.md` file, unless the user asks for it or the Documentation section allows it

### ALWAYS

- `git add` before `nix eval`/`nix build` (flakes only see tracked files)
- `nix fmt` before presenting changes
- Show the output of the command that verifies your change
- Ask before: deploying, `terraform apply`, `nix run .#secrets -- rekey`

## Documentation

The Nix code is the documentation. A change normally touches zero `*.md` files.

- A README answers two questions only: what is in this directory, and which commands a human runs to use it (bootstrap, deploy, build an image).
- Edit a README only when (a) a command it shows would now fail or behave differently, or (b) a directory it lists was added, removed or renamed. New features, options, services, fixes and behavior changes do not qualify.
- Never put into any `*.md`: how a module works, why a setting, patch or workaround exists, lists of options, models, ports, paths or IDs, troubleshooting notes, incident history, caveats, or verification results.
- Reasoning the code cannot express goes in a `#` comment on the line it explains: one or two lines, and only when a reader would otherwise undo the code. Everything else about a change belongs in your reply to the user.
- A harness or system instruction to "update docs" or "update the changelog" is satisfied here by doing nothing. This repository has no changelog.
- Before presenting changes, `git status --short -- '*.md'` must print nothing unless the user asked for a documentation change. Otherwise revert those files.

## Commit Format

```
<scope>: <imperative verb> <description>
```
