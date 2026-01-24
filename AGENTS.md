# PROJECT KNOWLEDGE BASE

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles. Infrastructure-as-Code with Terranix.

## Quick Commands

```bash
nix develop -c $SHELL    # Enter dev shell
nix fmt                  # Format all code
nix flake check          # Validate configuration
nix develop .#repl       # REPL for inspecting values
```

## Agents

This repository uses specialized agents for different tasks:

| Agent | Mode | Use For |
|-------|------|---------|
| `nix-planner` | primary | Planning tasks, coordinating work (use Tab to switch) |
| `@nix-researcher` | subagent | Research NixOS options, docs, patterns |
| `@nix-coder` | subagent | Implement Nix code changes |
| `@nix-security-reviewer` | subagent | Security audit before commit |

### Typical Workflow

1. **Start with planner** (Tab to switch agents)
2. Planner invokes `@nix-researcher` to gather information
3. Planner analyzes options and creates task spec
4. Planner invokes `@nix-coder` to implement
5. Planner reviews and invokes `@nix-security-reviewer` if needed

## Rules

### NEVER
- **Commit or push changes** — always leave git operations to the user
- Reference secrets directly (`"/run/agenix/..."`) — use `config.age.secrets.<name>.path`
- Write raw `.tf` files — use Terranix Nix expressions
- Run `terraform` directly — use `nix run .#tfmgr --`
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders — they inject required modules
- Use `config.services.*` when `config.codgician.*` exists
- Create overlays without user approval
- Claim "done" without showing verification output

### ALWAYS
- Run `nix fmt` before presenting changes
- Run `nix flake check` to validate
- Run `git add` before `nix eval/build` — flakes only see tracked files
- Show actual command output when claiming completion
- Request approval for: deploy, `tfmgr apply`, `agenix -r`, state mutations
- Run security review before changes to: `secrets/`, `modules/*/services/`, `packages/terraform-config/`, `hosts/`
- Leave committing and pushing to the user

## Skills

### Facts (Domain Knowledge)

| Skill | When to Load |
|-------|--------------|
| `fact-nix` | Working with flake, modules, hosts, lib.codgician |
| `fact-infra` | Working with Terraform/Terranix |
| `fact-secrets` | Working with Agenix secrets |

### Procedures

| Task | Skill |
|------|-------|
| Add NixOS host | `skill-add-nixos-host` |
| Add macOS host | `skill-add-darwin-host` |
| Add service module | `skill-add-service` |
| Deploy changes | `skill-build-deploy` |
| Fix eval/build errors | `skill-debug-eval` |
| Terraform changes | `skill-terraform-workflow` |
| Add/modify secrets | `skill-manage-agenix` |
| Security review | `skill-security-review` |

### Methodologies

| Skill | When to Apply |
|-------|---------------|
| `meta-verify-before-completion` | Before claiming any task is done |
| `meta-systematic-approach` | When analyzing problems or options |

## Hosts Reference

| Host | Platform | Type |
|------|----------|------|
| furina | aarch64-darwin | Mac (Apple Silicon) |
| raiden-ei | x86_64-darwin | Mac (Intel) |
| paimon | x86_64-linux | Primary server |
| fischl | x86_64-linux | Hypervisor |
| lumine | aarch64-linux | Azure VM |
| xianyun | x86_64-linux | Tencent VM |

## Commit Format

```
<scope>: <imperative verb> <description>
```

Examples: `jellyfin: init module`, `paimon: deploy grafana`, `secrets: add myservice-env`
