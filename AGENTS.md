# PROJECT KNOWLEDGE BASE

## OVERVIEW

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles. Infrastructure-as-Code with Terranix for cloud resources (Azure, Cloudflare, GCP).

## STRUCTURE

```
serenitea-pot/
├── flake.nix         # Entry point - defines all outputs
├── lib/              # Custom lib.codgician namespace
├── hosts/            # Machine configs, auto-discovered
│   ├── darwin/       # macOS: furina, raiden-ei
│   └── nixos/        # Linux: fischl, focalors, lumine, nahida, paimon, sandrone, wanderer, xianyun
├── modules/          # System-level NixOS/Darwin modules
│   ├── generic/      # Cross-platform (users, nix settings)
│   ├── darwin/       # macOS-specific (brew, system)
│   └── nixos/        # Linux-specific (services, virtualization)
├── hm-modules/       # User-level Home Manager modules (dotfiles, apps)
├── packages/         # Custom derivations + terraform-config/
├── overlays/         # Package overrides (00-* first, 99-* last)
├── secrets/          # Agenix-encrypted .age files
├── apps/             # CLI tools: tfmgr, chkexp, mkimg, mkjwe
└── shells/           # Dev environments: default, cloud, repl
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new host | `hosts/{darwin,nixos}/<name>/default.nix` | Auto-discovered; use `lib.codgician.mk{Darwin,Nixos}System` |
| Add NixOS service | `modules/nixos/services/<name>/default.nix` | Must define `options.codgician.services.<name>` |
| Add secret | `secrets/` | Edit `secrets.nix` + `pubkeys.nix`, run `agenix -e <name>.age` |
| Modify user dotfiles | `hm-modules/codgi/` | Split by `generic/`, `darwin/`, `nixos/` |
| Add system module | `modules/{generic,darwin,nixos}/` | For system-level config (not user) |
| Add package overlay | `overlays/XX-name/default.nix` | XX = load order (00 first, 99 last) |
| Add DNS record | `packages/terraform-config/cloudflare/zones/codgician-me/records/` | Terranix |
| Add AI model | `packages/terraform-config/celestia/cognitive/akasha/<model>.nix` | Azure OpenAI |

## HOSTS

Auto-discovered via `lib.codgician.getFolderNames` - just create a folder with `default.nix`.

| Host | Type | Platform | Notes |
|------|------|----------|-------|
| furina | Physical Mac | aarch64-darwin | M-series |
| raiden-ei | Physical Mac | x86_64-darwin | Intel |
| fischl | Bare metal | x86_64-linux | Hypervisor |
| paimon | Bare metal | x86_64-linux | Primary server |
| sandrone | Bare metal | x86_64-linux | CIX 8180 |
| focalors | VM | x86_64-linux | Parallels Desktop |
| nahida | Container | x86_64-linux | LXC |
| lumine | Cloud VM | aarch64-linux | Azure |
| xianyun | Cloud VM | x86_64-linux | Tencent Cloud |
| wanderer | WSL | x86_64-linux | Windows Subsystem |

## LIB.CODGICIAN FUNCTIONS

Custom library at `lib/` extending `nixpkgs.lib`.

| Function | Purpose |
|----------|---------|
| `mkNixosSystem` / `mkDarwinSystem` | Build system config with base modules |
| `mkServiceReverseProxyOptions` | Standard options for web services |
| `mkServiceReverseProxyConfig` | Generate Nginx vhost from options |
| `getFolderPaths` / `getFolderNames` | Auto-discover subdirectories |
| `getAgeSecretPathFromName` | Map secret name to .age path |

## CONVENTIONS

### Naming (Genshin Impact theme)

| Type | Rule | Examples |
|------|------|----------|
| VMs/Containers | Archons/Dragons | focalors, nahida |
| Bare metal | Human characters | fischl, paimon, sandrone |
| macOS | Female characters | furina, raiden-ei |
| aarch64 | Fontaine/Descenders | furina, lumine |

### Module Options Pattern

```nix
options.codgician.<category>.<name> = { ... };
cfg = config.codgician.<category>.<name>;  # In let block
```

### Secret Access

```nix
# Always use config.age.secrets, never direct paths
config.age.secrets.<name>.path
```

### Terranix Resource References

```nix
# Use Nix attribute access, never Terraform interpolation
config.resource.azurerm_storage_account.primogems "id"
```

## SKILLS

Procedural workflows in `.opencode/skills/`. Each skill has:
- `SKILL.md` - Quick start, procedure, exit criteria
- `TROUBLESHOOTING.md` - Error patterns, recovery steps
- `EXAMPLES.md` - Reference implementations

### Decision Logic

| If you are... | Use skill... |
|---------------|--------------|
| Adding/modifying secrets | [manage-agenix](.opencode/skills/secrets/manage-agenix/SKILL.md) |
| Adding a NixOS host | [add-nixos-host](.opencode/skills/nix/add-nixos-host/SKILL.md) |
| Adding a macOS host | [add-darwin-host](.opencode/skills/nix/add-darwin-host/SKILL.md) |
| Adding a service module | [add-service](.opencode/skills/nix/add-service/SKILL.md) |
| Changing Terranix/Terraform | [terraform-workflow](.opencode/skills/infra/terraform-workflow/SKILL.md) |
| Deploying changes | [build-deploy](.opencode/skills/nix/build-deploy/SKILL.md) |
| Fixing eval/build errors | [debug-eval](.opencode/skills/nix/debug-eval/SKILL.md) |
| Before committing sensitive changes | [security-review](.opencode/skills/review/security-review/SKILL.md) |

### When Security Review MUST Run

Before ANY commit touching: `secrets/`, `modules/*/services/`, `packages/terraform-config/`, `hosts/`

## ANTI-PATTERNS

- **NEVER** include secrets in ISO builds (`installer-iso*`)
- **NEVER** reference secrets directly - use `config.age.secrets.<name>.path`
- **NEVER** bypass `mk*System` - it injects required modules
- **NEVER** write raw `.tf` files - use Terranix expressions
- **NEVER** run `terraform` directly - use `tfmgr` (terraform allowed only inside `tfmgr shell`)

## COMMIT CONVENTIONS

### Format

```
<scope>: <imperative verb> <concise description>
```

- **NO** conventional commit prefixes (`feat:`, `fix:`, `chore:`)
- Scope = component/host/module name (`overlays:`, `furina:`, `nixos/common:`)
- Imperative verbs: `add`, `update`, `fix`, `remove`, `init`, `deploy`
- Brief (3-8 words), lowercase, single-line

### Examples

```
overlays: update fishspeech patch
openvscode-server: init module
paimon: deploy qwen3-vl:8b
nixos/common: disable audit by default
```

### Commit/Push Protocol

**ALWAYS obtain user approval before committing:**

1. Show summary of changes (files modified, what was done)
2. Propose commit message following format above
3. **Wait for explicit approval** before `git commit`
4. After commit, **wait for approval** before `git push`

Work is complete only after changes are **approved and pushed**.

## QUICK REFERENCE

```bash
nix develop -c $SHELL              # Enter dev shell
nix develop .#repl                 # REPL for inspecting values
nix fmt                            # Format all code
nix flake check                    # Validate configuration
agenix -e secrets/<name>.age       # Edit secret
nix run .#tfmgr -- plan            # Preview terraform changes
nix run .#tfmgr -- apply           # Apply terraform changes
```

For build/deploy commands, see [build-deploy](.opencode/skills/nix/build-deploy/SKILL.md) skill.

## NOTES

- Binary cache: `codgician.cachix.org`
- CI: Garnix (not GitHub Actions for builds)
- `pkgs.unstable.*` available via lazy overlay
- Impermanence: Register paths with `codgician.system.impermanence.extraItems`
- Terraform auth: Auto-decrypted by `tfmgr` from `secrets/terraform-env.age`
