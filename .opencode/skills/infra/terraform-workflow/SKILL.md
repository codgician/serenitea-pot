---
name: terraform-workflow
description: Plan and apply Terraform/Terranix infrastructure changes using tfmgr.
tags: [terraform, terranix, infrastructure, dns, tfmgr]
when_to_use: User needs to plan/apply Terraform, add DNS records, or modify cloud resources
blast_radius: HIGH
---

# Terraform Workflow

## Quick Start

All operations via `tfmgr`. Never run `terraform` directly (except inside `tfmgr shell`).

```bash
nix run .#tfmgr -- plan    # Preview
nix run .#tfmgr -- apply   # Apply (after review)
```

## Required Inputs

- [ ] **Resource type** (DNS, Azure, GCP)
- [ ] **Zone/region**
- [ ] **Resource details** (name, type, content)

## Safety Rules

- ❌ **NEVER** write raw `.tf` files - use Terranix Nix expressions
- ❌ **NEVER** apply without reviewing plan
- ❌ **NEVER** run `terraform` directly (allowed only inside `tfmgr shell`)
- ❌ **NEVER** use `${...}` interpolation - use Nix attribute access
- ⚠️ **REVIEW** IAM/credential changes carefully

---

# Terranix Structure

```
packages/terraform-config/
├── cloudflare/zones/codgician-me/records/  # DNS
├── celestia/cognitive/                      # Azure AI
├── celestia/iam/                            # Azure IAM
└── tonatiuh/                                # GCP
```

## Nix Syntax (NOT HCL)

```nix
# ✅ CORRECT: Nix attribute access
zone_id = config.resource.cloudflare_zone.codgician-me "id";

# ❌ WRONG: Terraform interpolation
zone_id = "\${cloudflare_zone.codgician-me.id}";
```

---

# tfmgr Commands

```bash
nix run .#tfmgr -- validate          # Validate config
nix run .#tfmgr -- plan              # Preview changes
nix run .#tfmgr -- apply             # Apply changes (requires approval)
nix run .#tfmgr -- shell             # Advanced: terraform CLI access
```

> ⚠️ `--auto-approve` exists but should only be used if user explicitly requests it.

**Inside `tfmgr shell`** (for state/import operations):

> ⚠️ State mutations (`import`, `refresh`, `state rm`) require user approval.

```bash
terraform state list
terraform state show <resource>
terraform import <resource> <id>
```

---

# Procedure: Add DNS Record

## Phase 1: Create File

```bash
touch packages/terraform-config/cloudflare/zones/codgician-me/records/<name>.nix
```

## Phase 2: Write Record

```nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record.<name>-cname = {
    name = "<name>.${zone_name}";
    type = "CNAME";
    content = "paimon.codgician.me";
    proxied = false;
    ttl = 1;  # 1 = auto
    inherit zone_id;
  };
}
```

## Phase 3: Plan

```bash
nix run .#tfmgr -- plan
```

**Review output**:
| Symbol | Meaning |
|--------|---------|
| `+` | Create |
| `-` | ⚠️ Destroy |
| `~` | Update |
| `-/+` | ⚠️ Replace |

## Phase 4: Apply (User Approval Required)

⚠️ **STOP**: `terraform apply` changes infrastructure. Ask user before proceeding.

```bash
nix run .#tfmgr -- apply
```

## Phase 5: Verify

```bash
dig <name>.codgician.me
```

---

# Exit Criteria

- [ ] Changes in Terranix Nix files
- [ ] `tfmgr validate` passes
- [ ] `tfmgr plan` shows expected changes
- [ ] No unexpected destroys
- [ ] `tfmgr apply` completes
- [ ] Resources verified

---

# Commit (User Approval Required)

First, format all code:
```bash
nix fmt
```

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- packages/terraform-config/.../records/<name>.nix (new/modified)

Terraform plan: +1 resource

Proposed: `cloudflare: add <name> dns record`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

# Examples

## Example 1: Simple CNAME Record

```nix
# packages/terraform-config/cloudflare/zones/codgician-me/records/grafana.nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record.grafana-cname = {
    name = "grafana.${zone_name}";
    type = "CNAME";
    content = "paimon.codgician.me";
    proxied = false;
    ttl = 1;
    inherit zone_id;
  };
}
```

## Example 2: Multiple Records (A + AAAA)

```nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record = {
    myhost-a = {
      name = "myhost.${zone_name}";
      type = "A";
      content = "1.2.3.4";
      proxied = false;
      ttl = 120;
      inherit zone_id;
    };

    myhost-aaaa = {
      name = "myhost.${zone_name}";
      type = "AAAA";
      content = "2001:db8::1";
      proxied = false;
      ttl = 120;
      inherit zone_id;
    };
  };
}
```

## Example 3: Cross-Provider Reference (Azure)

```nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record.myvm-a = {
    name = "myvm.${zone_name}";
    type = "A";
    # Reference Azure VM's public IP
    content = config.resource.azurerm_linux_virtual_machine.myvm "public_ip_addresses[0]";
    proxied = false;
    ttl = 120;
    inherit zone_id;
  };
}
```

## Common Record Patterns

| Type | Use Case | Example content |
|------|----------|-----------------|
| A | IPv4 address | `"1.2.3.4"` |
| AAAA | IPv6 address | `"2001:db8::1"` |
| CNAME | Alias | `"paimon.codgician.me"` |
| MX | Mail | `"mail.example.com"` (+ priority) |
| TXT | Verification | `"v=spf1 ..."` |

## tfmgr shell: Import Existing Resource

```bash
nix run .#tfmgr -- shell

terraform state list
terraform state show cloudflare_dns_record.example
terraform import cloudflare_dns_record.newrecord <zone_id>/<record_id>

exit
```

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [security-review](../../review/security-review/SKILL.md) — Reviews IAM changes
- [add-service](../../nix/add-service/SKILL.md) — Services need DNS
- [manage-agenix](../../secrets/manage-agenix/SKILL.md) — Terraform credentials
