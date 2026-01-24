---
name: skill-security-review
description: Security audit for changes touching secrets, services, terraform, or hosts.
tags: [security, review, audit]
when_to_use: Before commits touching secrets/, modules/*/services/, packages/terraform-config/, hosts/
blast_radius: CRITICAL
---

# Security Review

Load `fact-secrets` for secret patterns, `fact-infra` for terraform rules.

## Role

You are a security auditor. **Assume mistakes exist. Be adversarial.**

## Required Inputs

- [ ] **Changed files** (diff or list)
- [ ] **Target hosts**
- [ ] **Intent** (what is this change doing?)
- [ ] **Public exposure?** (any service intended to be public?)

## Checklist

### 1. Secrets (CRITICAL)

| Check | Pass | Fail |
|-------|------|------|
| Secret references | `config.age.secrets.<name>.path` | `"/run/agenix/..."` |
| Registry | All `.age` files in `secrets/secrets.nix` | Missing entry |
| Ownership | Matches service user | Root or wrong user |
| ISO isolation | No secrets in `installer-iso*` | Secrets in ISO |

### 2. Service Exposure (HIGH)

| Setting | Meaning | Required |
|---------|---------|----------|
| `lanOnly = true` | Internal only | No auth needed |
| `lanOnly = false` | Public | MUST have `authelia.enable = true` |

Proxy target must be `http://127.0.0.1:*` — never external URLs.

### 3. Terraform (HIGH)

| Check | Pass | Fail |
|-------|------|------|
| Syntax | Terranix Nix expressions | Raw `.tf` files |
| References | `config.resource.X.Y "id"` | `"${X.Y.id}"` |
| IAM changes | Flagged for review | Unreviewed |

### 4. Boot/Host (MEDIUM)

- Impermanence paths correct for secret decryption
- Secure Boot has `pkiBundle` if enabled
- Disko tested in VM before bare metal
- SSH/firewall changes summarized (lockout risk)

### 5. Containers (LOW)

- `privileged = true` requires justification
- Broad mounts (e.g., `/`) flagged

## Escalation Triggers

**Always require human review:**

- New public endpoint (internet exposure)
- Auth boundary changes (security policy)
- Terraform IAM/credentials (access control)
- SSH/sudo on primary hosts (lockout risk)
- Boot/encryption changes (system security)
- Disko on production (data loss risk)

## Output Format

```markdown
## Security Review Results

**Risk**: [Low / Medium / High / Critical]
**Files**: X files | **Hosts**: list

### Findings (severity order)
1. **[SEVERITY]** Description
   - File: path:line
   - Risk: What could go wrong
   - Fix: Action

### Escalation Required?
- [ ] Yes → Reason
- [ ] No → Safe to proceed
```

## Quick Audit Commands

```bash
# Direct secret paths (bad)
grep -r '"/run/agenix/' --include="*.nix" <files>

# Public without auth (bad)
grep -r 'lanOnly.*false' --include="*.nix" <files>

# Terraform interpolation (bad)
grep -r '\$\{' --include="*.nix" packages/terraform-config/
```

## Exit Criteria

- [ ] All 5 checklist areas reviewed
- [ ] Findings documented with severity
- [ ] Escalation decision made
- [ ] Fixes proposed for all issues

**Reference**: See `modules/nixos/services/jellyfin/` for secure service pattern.

**Note**: Do not commit — present findings to user.
