# PROJECT KNOWLEDGE BASE

**Generated:** 2025-01-09
**Commit:** ea4ee37
**Branch:** main

## OVERVIEW

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles. Infrastructure-as-Code with Terranix for cloud resources (Azure, Cloudflare, GCP).

## STRUCTURE

```
serenitea-pot/
├── flake.nix         # Entry point - defines all outputs
├── lib/              # Custom lib.codgician namespace (see lib/AGENTS.md)
├── hosts/            # Machine configs by OS type (see hosts/AGENTS.md)
│   ├── darwin/       # macOS: furina, raiden-ei
│   └── nixos/        # Linux: fischl, focalors, lumine, nahida, paimon, sandrone, wanderer, xianyun
├── modules/          # Reusable NixOS/Darwin modules
│   ├── generic/      # Cross-platform (users, nix settings)
│   ├── darwin/       # macOS-specific (brew, system)
│   └── nixos/        # Linux-specific (services, virtualization)
├── hm-modules/       # Home Manager modules (codgi user config)
├── packages/         # Custom derivations + terraform-config/ (see terraform-config/AGENTS.md)
├── overlays/         # Package overrides (numbered for ordering)
├── secrets/          # Agenix-encrypted .age files
├── apps/             # CLI tools: tfmgr, chkexp, mkimg, mkjwe
└── shells/           # Dev environments: default, cloud, repl
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new host | `hosts/{darwin,nixos}/<name>/` | Use `lib.codgician.mk{Darwin,Nixos}System` |
| Add NixOS service | `modules/nixos/services/<name>/` | Use `mkServiceReverseProxyOptions` for web services |
| Add secret | `secrets/` | Edit `secrets.nix`, run `agenix -e <name>.age` |
| Modify user config | `hm-modules/codgi/` | Split by `generic/`, `darwin/`, `nixos/` |
| Add package overlay | `overlays/XX-name/` | Numbered prefix controls load order |
| Terraform changes | `packages/terraform-config/` | Terranix (Nix->TF JSON) |

## CONVENTIONS

### Naming (Genshin Impact theme)
- **VMs**: Archons/Dragons (furina, nahida, focalors)
- **Bare metal**: Human characters (fischl, paimon)
- **Unix-like OS**: Female characters
- **Non-x86 (aarch64)**: Fontaine/Descenders (furina, lumine)

### Module Options
- Namespace: `options.codgician.<category>.<name>`
- Pattern: `cfg = config.codgician.<category>.<name>;` in let block
- Service backends: Support both `nixpkgs` and `container` via `backend` option

### Files per Host
- `default.nix` - Entry point calling mk*System
- `system.nix` - Core system config
- `hardware.nix` - (NixOS) Boot, drivers, kernel modules
- `disks.nix` - (NixOS) Disko partitioning

## ANTI-PATTERNS (THIS PROJECT)

- **NEVER** include secrets in ISO builds (`installer-iso*`)
- **NEVER** stop before `git push` - work is NOT complete until pushed
- **NEVER** say "ready to push when you are" - YOU must push
- Check RAID-1 status on `paimon`/`fischl` if boot warnings appear
- Postfix requires manual SASL OAuth2 token creation

## COMMANDS

```bash
# Development
nix develop -c $SHELL          # Enter dev shell
nix develop .#repl             # REPL for inspecting values
nix fmt                        # Format all code (treefmt)

# Building
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#darwinConfigurations.<host>.system

# Secrets
agenix -e secrets/<name>.age   # Edit/create secret

# Terraform
nix run .#tfmgr                # Terraform management wrapper
```

## NOTES

- Binary cache: `codgician.cachix.org` (add to substituters)
- CI: Garnix (not GitHub Actions for builds)
- `lib.codgician.forAllSystems` for cross-platform packages
- `pkgs.unstable.*` available via lazy overlay
- Impermanence: Services must register persistent paths with `codgician.system.impermanence`
