---
name: fact-infra
description: Infrastructure domain knowledge - Terranix structure, syntax, and tfmgr commands
---

# Infrastructure Domain Knowledge

## Directory Layout

```
packages/terraform-config/
├── cloudflare/           # Cloudflare provider
│   └── zones/
│       └── codgician-me/
│           ├── default.nix       # Zone definition
│           └── records/          # DNS records (auto-discovered)
├── celestia/             # Azure provider
│   ├── cognitive/akasha/ # OpenAI deployments
│   ├── iam/              # Service principals
│   └── storage/          # Storage accounts
└── tonatiuh/             # GCP provider
```

Files are auto-imported. Just create a `.nix` file.

## Terranix Syntax (NOT HCL)

### Resource References

```nix
# ✅ CORRECT: Nix attribute access (function call)
zone_id = config.resource.cloudflare_zone.codgician-me "id";

# ❌ WRONG: Terraform interpolation
zone_id = "${cloudflare_zone.codgician-me.id}";
```

### DNS Record Example

```nix
{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in {
  resource.cloudflare_dns_record.myservice-cname = {
    name = "myservice.${zone_name}";
    type = "CNAME";
    content = "paimon.codgician.me";
    proxied = false;
    ttl = 1;  # 1 = auto
    inherit zone_id;
  };
}
```

### Record Types

| Type | Content Example |
|------|-----------------|
| A | `"1.2.3.4"` |
| AAAA | `"2001:db8::1"` |
| CNAME | `"paimon.codgician.me"` |
| MX | `"mail.example.com"` |
| TXT | `"v=spf1 ..."` |

## tfmgr Commands

**Never run `terraform` directly** — use `tfmgr`.

| Command | Purpose | Approval |
|---------|---------|----------|
| `nix run .#tfmgr -- validate` | Validate config | No |
| `nix run .#tfmgr -- plan` | Preview changes | No |
| `nix run .#tfmgr -- apply` | Apply changes | **Yes** |
| `nix run .#tfmgr -- shell` | Interactive CLI | State ops need approval |

### Plan Symbols

| Symbol | Meaning | Risk |
|--------|---------|------|
| `+` | Create | Low |
| `~` | Update | Medium |
| `-` | Destroy | High |
| `-/+` | Replace | High |

### Workflow

1. Create/edit `.nix` file in `packages/terraform-config/`
2. `nix run .#tfmgr -- validate`
3. `nix run .#tfmgr -- plan`
4. Review output, request approval
5. `nix run .#tfmgr -- apply`
6. Verify (e.g., `dig myservice.codgician.me`)
