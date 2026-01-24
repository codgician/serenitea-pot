---
name: skill-terraform-workflow
description: Plan and apply Terraform/Terranix infrastructure changes using tfmgr.
tags: [terraform, terranix, dns]
when_to_use: User needs to plan/apply Terraform, add DNS records, or modify cloud resources
blast_radius: HIGH
---

# Terraform Workflow

Load `fact-infra` for Terranix syntax and structure.

## Required Inputs

- [ ] **Resource type** (DNS record, Azure resource, etc.)
- [ ] **Provider** (cloudflare, celestia/Azure, tonatiuh/GCP)
- [ ] **Resource details**

## Safety Rules

- ❌ **NEVER** write raw `.tf` files — use Terranix Nix
- ❌ **NEVER** use `${...}` interpolation — use `config.resource.X.Y "attr"`
- ❌ **NEVER** apply without reviewing plan
- ⚠️ **ESCALATE** IAM/credential changes

## Commands

```bash
nix run .#tfmgr -- validate    # Check syntax
nix run .#tfmgr -- plan        # Preview (safe)
nix run .#tfmgr -- apply       # Apply (requires approval)
nix run .#tfmgr -- shell       # Interactive terraform CLI
```

## Procedure: Add DNS Record

### 1. Create File

```bash
touch packages/terraform-config/cloudflare/zones/codgician-me/records/<name>.nix
```

### 2. Write Terranix

```nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in {
  resource.cloudflare_dns_record.<name>-cname = {
    name = "<name>.${zone_name}";
    type = "CNAME";
    content = "paimon.codgician.me";
    proxied = false;
    ttl = 1;
    inherit zone_id;
  };
}
```

### 3. Plan and Review

```bash
nix run .#tfmgr -- plan
```

| Symbol | Meaning |
|--------|---------|
| `+` | Create |
| `~` | Update |
| `-` | ⚠️ Destroy |
| `-/+` | ⚠️ Replace |

### 4. Apply (User Approval Required)

```bash
nix run .#tfmgr -- apply
```

### 5. Verify

```bash
dig <name>.codgician.me
```

## Exit Criteria

- [ ] Terranix `.nix` file created
- [ ] `tfmgr plan` shows expected changes
- [ ] No unexpected destroys
- [ ] `tfmgr apply` completes
- [ ] Resource verified

**Reference**: See `packages/terraform-config/cloudflare/` for DNS examples.

**Note**: Do not commit — present changes to user.
