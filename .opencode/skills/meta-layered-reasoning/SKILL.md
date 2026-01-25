---
name: meta-layered-reasoning
description: Methodology - trace problems through cognitive layers before proposing solutions (Domain → Design → Mechanics)
---

# Layered Reasoning Methodology

**Core principle**: Don't answer directly. Trace through cognitive layers first.

## The Three Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Domain Constraints (WHY)                          │
│  ├── What is the actual requirement?                        │
│  ├── What security/compliance constraints apply?            │
│  └── What are the operational needs?                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Design Choices (WHAT)                             │
│  ├── What pattern fits this requirement?                    │
│  ├── Wrapper module vs direct service vs custom systemd?    │
│  └── What are the trade-offs?                               │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Language/Tool Mechanics (HOW)                     │
│  ├── Nix syntax, flake structure, eval errors               │
│  ├── NixOS module system, option types                      │
│  └── Terraform/Terranix, Agenix commands                    │
└─────────────────────────────────────────────────────────────┘
```

## Identify Entry Point

| User Signal | Entry Layer | Trace Direction |
|-------------|-------------|-----------------|
| Eval error, syntax error, attribute not found | Layer 1 | Trace UP ↑ |
| "How to design...", "should I use..." | Layer 2 | Check L3, then DOWN ↓ |
| "Add service X", "I need Y capability" | Layer 3 | Trace DOWN ↓ |
| "Why does NixOS...", "what's the pattern for..." | Layer 2 | Bidirectional ↕ |

## Layer-Specific Questions

### Layer 1: Mechanics (HOW)

| Problem | Core Question |
|---------|---------------|
| Eval error | "Where is this attribute expected to come from?" |
| Infinite recursion | "What circular dependency exists?" |
| Type mismatch | "What type is expected vs provided?" |
| Build failure | "Is this a derivation issue or config issue?" |

### Layer 2: Design (WHAT)

| Problem | Core Question |
|---------|---------------|
| Module structure | "Wrapper around existing service or custom systemd?" |
| Option design | "What does the user need to configure vs what should be hardcoded?" |
| Secret handling | "Environment file, separate secrets, or config template?" |
| Data persistence | "What needs to survive reboots? Is impermanence relevant?" |

### Layer 3: Domain (WHY)

| Problem | Core Question |
|---------|---------------|
| New service | "What problem does this solve? Who uses it?" |
| Security | "What access level? LAN-only, authenticated, or public?" |
| Infrastructure | "Does this need DNS, reverse proxy, or external access?" |
| Compliance | "Are there secrets, audit requirements, or data retention needs?" |

## Trace Examples

### Example 1: Eval Error (Entry: Layer 1)

```
User: "error: attribute 'jellyfin' not found in 'config.services'"

❌ Surface answer: "Check spelling, maybe it's config.services.jellyfin"

✅ Layered answer:
├── Layer 1: Attribute not found in config.services
│      ↑ Ask: Where should this service be defined?
├── Layer 2: This repo uses codgician.services namespace, not services
│      ↑ Ask: Why the custom namespace?
└── Layer 3: Wrapper pattern allows adding reverseProxy, impermanence
       ↓
Solution: Use config.codgician.services.jellyfin, not config.services.jellyfin
Insight: This repo wraps NixOS services with additional options
```

### Example 2: Add Service Request (Entry: Layer 3)

```
User: "Add Jellyfin to paimon"

❌ Surface answer: "Set services.jellyfin.enable = true"

✅ Layered answer:
├── Layer 3: Media server for home use
│      ↓ Ask: Access requirements? Security?
│      Answer: LAN access, maybe VPN, needs data persistence
├── Layer 2: Need wrapper module with reverseProxy, impermanence
│      ↓ Ask: What pattern fits?
│      Answer: Follow skill-add-service procedure
└── Layer 1: Create modules/nixos/services/jellyfin/default.nix
       using lib.codgician helpers

Solution: Full wrapper module, not just enable = true
```

### Example 3: Design Question (Entry: Layer 2)

```
User: "Should I use an overlay or a package for this custom build?"

✅ Layered answer:
├── Layer 2: Overlay vs package trade-offs
│      ↑ Ask: What's the use case?
├── Layer 3: Is this a patch to existing package or new software?
│      - Patch to existing → overlay (inherits updates)
│      - New software → packages/ (explicit versioning)
│      ↓
└── Layer 1: Overlay in overlays/, package in packages/

Decision depends on: update behavior, scope of change, reusability
```

## Anti-Patterns

### Don't: Answer at Surface Level

```
User: "infinite recursion error"
❌ Bad: "You have a circular import somewhere"
✅ Good: Trace to understand WHY the recursion exists (often design issue)
```

### Don't: Skip Layers

```
User: "Add monitoring to my server"
❌ Bad: "Use services.prometheus.enable = true" (jumped to L1)
✅ Good: First understand what to monitor (L3), then design (L2), then implement (L1)
```

### Don't: Ignore Context

```
User: "How do I read a secret in my service?"
❌ Bad: "Use builtins.readFile" (ignores this repo's patterns)
✅ Good: Use config.age.secrets.<name>.path with agenix registration
```

## Integration with Skills

| Layer | Skills to Load |
|-------|----------------|
| Layer 3 (Domain) | fact-nix (hosts, purpose), fact-secrets (access groups) |
| Layer 2 (Design) | fact-nix (patterns), skill-add-service, skill-security-review |
| Layer 1 (Mechanics) | skill-debug-eval, fact-infra (terranix syntax) |

## 5-Question Reboot

When stuck, answer these:

1. **What problem am I solving?** (Original request)
2. **What layer am I in?** (Mechanics, Design, or Domain)
3. **What constraints apply?** (Security, patterns, host capabilities)
4. **What have I tried?** (Previous approaches)
5. **Which direction should I trace?** (Up for errors, down for features)
