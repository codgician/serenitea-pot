# OpenCode Architecture

## Overview

This repository uses a structured agent + skill system for AI-assisted development.

## Directory Structure

```
.opencode/
├── agents/                    # Project-local agent definitions
│   ├── nix-planner.md        # Primary orchestrator (planning, coordination)
│   ├── nix-researcher.md     # Research subagent (options, docs, patterns)
│   ├── nix-coder.md          # Implementation subagent (writes code)
│   └── nix-security-reviewer.md  # Security audit subagent
│
└── skills/                    # Project-local skills
    ├── fact-nix/             # Nix domain knowledge
    ├── fact-infra/           # Terraform/Terranix knowledge
    ├── fact-secrets/         # Agenix knowledge
    │
    ├── meta-layered-reasoning/      # Methodology: 3-layer cognitive model
    ├── meta-verify-before-completion/   # Methodology: verify before claiming done
    ├── meta-systematic-approach/        # Methodology: structured problem solving
    │
    ├── skill-add-nixos-host/     # Procedure: add NixOS host
    ├── skill-add-darwin-host/    # Procedure: add macOS host
    ├── skill-add-service/        # Procedure: add service module
    ├── skill-build-deploy/       # Procedure: build and deploy
    ├── skill-debug-eval/         # Procedure: debug eval errors
    ├── skill-manage-agenix/      # Procedure: manage secrets
    ├── skill-security-review/    # Procedure: security audit
    └── skill-terraform-workflow/ # Procedure: terraform changes
```

## Layered Reasoning Model

Inspired by [rust-skills](https://github.com/actionbook/rust-skills), this repo uses a 3-layer cognitive model to avoid surface-level answers.

### The Three Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Domain Constraints (WHY)                          │
│  ├── What problem does this solve?                          │
│  ├── What security/compliance constraints apply?            │
│  └── What are the operational needs?                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Design Choices (WHAT)                             │
│  ├── Wrapper module vs direct service vs custom systemd?    │
│  ├── What pattern fits this requirement?                    │
│  └── What are the trade-offs?                               │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Language/Tool Mechanics (HOW)                     │
│  ├── Nix syntax, flake structure, eval errors               │
│  ├── NixOS module system, option types                      │
│  └── Terraform/Terranix, Agenix commands                    │
└─────────────────────────────────────────────────────────────┘
```

### Trace Direction

| Entry Point | Direction | Example |
|-------------|-----------|---------|
| Error (L1) | Trace UP ↑ | `attribute not found` → Why is this structured this way? |
| Design Q (L2) | Bidirectional ↕ | "Should I use overlay?" → Check constraints, then mechanics |
| Feature (L3) | Trace DOWN ↓ | "Add Jellyfin" → What pattern? → What syntax? |

### Example: Don't Answer at Surface Level

```
User: "error: attribute 'jellyfin' not found in config.services"

❌ Surface answer: "Check if the module is imported"

✅ Layered answer:
├── Layer 1: Attribute not found in config.services
│      ↑ Trace up: Where should this be defined?
├── Layer 2: This repo uses codgician.services namespace
│      ↑ Trace up: Why custom namespace?
└── Layer 3: Wrapper pattern adds reverseProxy, impermanence
       ↓
Solution: Use config.codgician.services.jellyfin
Insight: Services in this repo are wrapped, not raw NixOS modules
```

### Core Questions (Per Skill)

Each skill includes a "Core Questions" table to guide layer-aware thinking:

| Layer | Question | Purpose |
|-------|----------|---------|
| L3 | "Which hosts does this affect?" | Scope and constraints |
| L2 | "Wrapper or direct service?" | Design decision |
| L1 | "What helpers exist?" | Implementation |

## Agent Architecture

### Skill Composition Model

Each agent combines four types of skills:

| Type | Prefix | Purpose | Example |
|------|--------|---------|---------|
| **Facts** | `fact-` | Domain knowledge | `fact-nix` (repo structure, patterns) |
| **Procedures** | `skill-` | Step-by-step workflows | `skill-add-service` |
| **Methodologies** | `meta-` | How to approach problems | `meta-layered-reasoning`, `meta-verify-before-completion` |

### Agent Roles

| Agent | Mode | Role | Key Skills |
|-------|------|------|------------|
| `nix-planner` | primary | Orchestrate, decide, coordinate | fact-nix, meta-layered-reasoning, meta-systematic-approach |
| `nix-researcher` | subagent | Research options, docs, patterns | fact-nix, fact-infra, fact-secrets |
| `nix-coder` | subagent | Implement code changes | All fact-*, skill-*, meta-verify |
| `nix-security-reviewer` | subagent | Security audit | fact-*, skill-security-review |

### Workflow Example: Adding a Service

```
User: "Add Jellyfin to paimon"
         │
         ▼
┌─────────────────────────────────────┐
│         nix-planner (primary)       │
│  • Understands request              │
│  • Invokes researcher               │
└──────────────┬──────────────────────┘
               │ @nix-researcher
               ▼
┌─────────────────────────────────────┐
│       nix-researcher (subagent)     │
│  • Finds services.jellyfin options  │
│  • Checks repo patterns             │
│  • Returns structured research      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         nix-planner                 │
│  • Analyzes options vs repo style   │
│  • Decides: wrapper pattern         │
│  • Creates task spec for coder      │
└──────────────┬──────────────────────┘
               │ @nix-coder
               ▼
┌─────────────────────────────────────┐
│        nix-coder (subagent)         │
│  • Implements module                │
│  • Runs nix fmt, nix flake check    │
│  • Reports with verification output │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         nix-planner                 │
│  • Reviews result                   │
│  • [If security-sensitive]          │
│    → @nix-security-reviewer         │
│  • Presents to user                 │
└─────────────────────────────────────┘
```

## Skill Types

### Facts (Domain Knowledge)

Consolidated knowledge about specific domains. Load for context before working in that area.

- **fact-nix**: Flake structure, lib.codgician, module patterns, hosts
- **fact-infra**: Terranix syntax, tfmgr commands, resource references
- **fact-secrets**: Agenix structure, access groups, secret patterns

### Procedures (Core Skills)

Step-by-step workflows for specific tasks. Follow when performing that task.

### Methodologies (Meta Skills)

How to approach problems. Apply as working style:

- **meta-verify-before-completion**: Always run verification, show output
- **meta-systematic-approach**: Research → Analyze → Decide → Execute

## Design Principles

1. **Agents in `.opencode/agents/`** — Project-local, markdown format
2. **Skills in `.opencode/skills/`** — Flat structure with prefixes
3. **Rules in `AGENTS.md`** — Always loaded, no overhead
4. **Separation of concerns** — Planner plans, coder codes, reviewer reviews
5. **Verification required** — Never claim done without evidence
