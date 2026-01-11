---
name: security-review
description: Security audit for changes touching secrets, services, terraform, or hosts.
tags: [security, review, audit]
when_to_use: Before commits touching secrets/, modules/*/services/, packages/terraform-config/, hosts/
blast_radius: CRITICAL
---

# Security Review

## Role

You are a security auditor. **Assume mistakes exist. Be adversarial.**

## Required Inputs

- [ ] **Changed files** (diff or list)
- [ ] **Target hosts**
- [ ] **Intent** (what is this change doing?)
- [ ] **Public exposure?** (any service intended to be public?)

## Output Format

```markdown
## Security Review Results

**Risk**: [Low / Medium / High / Critical]
**Files**: X files
**Hosts**: list

### Checklist
| Category | Status | Finding |
|----------|--------|---------|
| Secrets | ✅/❌/⚠️ | Details |

### Findings (severity order)
1. **[SEVERITY]** Description
   - File: path:line
   - Risk: What could go wrong
   - Fix: Action

### Escalation Required?
- [ ] Yes → Reason
- [ ] No → Safe to proceed
```

---

# Security Checklist

## 1. Secrets (Agenix) — CRITICAL 🔴

### References
- ✅ `config.age.secrets.<name>.path`
- ❌ `"/run/agenix/..."` or `secrets/....age`

### Registry
Every `.age` file must be in `secrets/secrets.nix`

### Ownership
Secrets must have correct owner/group/mode matching service user

### ISO Isolation
`installer-iso*` outputs must NEVER include secrets

---

## 2. Service Exposure — HIGH 🟠

### Every `reverseProxy.enable = true` must have explicit stance:

| Setting | Meaning | Required |
|---------|---------|----------|
| `lanOnly = true` | Internal | No auth needed |
| `lanOnly = false` | Public | MUST have `authelia.enable = true` |

### Proxy Target
- ✅ `http://127.0.0.1:8080`
- ❌ `https://external-api.com` (open proxy!)

---

## 3. Terraform — HIGH 🟠

### No Raw .tf
Only Terranix Nix expressions allowed

### IAM Changes
Auto-escalate if touching:
- `*/iam/*`
- `*_service_principal*`
- `*_access_key*`

### Resource References
- ✅ `config.resource.X.Y "id"`
- ❌ `"${X.Y.id}"`

---

## 4. Boot/Host — MEDIUM 🟡

### Impermanence
Identity paths must be correct for secrets to decrypt

### Secure Boot
Must have `pkiBundle` if enabled

### Disko
Test in VM before bare metal (wrong disk = data loss)

### SSH/Firewall
Summarize any changes (lockout risk)

---

## 5. Containers — LOW 🟢

### Privileged
`privileged = true` requires justification

### Capabilities
Document added capabilities

### Mounts
Avoid mounting `/` or broad paths

---

# Escalation Triggers

**Always require human review:**

| Trigger | Reason |
|---------|--------|
| New public endpoint | Internet exposure |
| Auth boundary changes | Security policy |
| Terraform IAM/credentials | Access control |
| SSH/sudo on primary hosts | Lockout risk |
| Boot/encryption changes | System security |
| Disko on production | Data loss risk |

---

# Examples

## ✅ Good: Secure Service Implementation

```nix
{
  options.codgician.services.example = {
    enable = lib.mkEnableOption "Example";
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      serviceName = "example";
      defaultHost = "example.codgician.me";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Secret via config.age (correct!)
    systemd.services.example.serviceConfig.EnvironmentFile = 
      config.age.secrets.example-env.path;
    
    # Proper ownership
    codgician.system.agenix.secrets = lib.genAttrs
      ["example-env"]
      (name: { owner = "example"; group = "example"; mode = "0600"; });
  };
}
```

**Review Result**: ✅ **PASS**

## ❌ Bad: Multiple Security Issues

```nix
{
  config = {
    # Issue 1: Direct secret path
    environment.variables.API_KEY = "/run/agenix/api-key";
    
    # Issue 2: Public without auth
    codgician.services.nginx.reverseProxies.admin = {
      enable = true;
      lanOnly = false;           # Public!
      authelia.enable = false;   # No auth!
    };
    
    # Issue 3: Terraform interpolation
    storage_id = "${azurerm_storage.main.id}";
  };
}
```

**Review Result**: ❌ **FAIL**
- 🔴 **CRITICAL**: Direct secret path (line 3)
- 🟠 **HIGH**: Public without auth (lines 6-9)
- 🟠 **HIGH**: Terraform interpolation (line 12)

## Quick Audit Commands

```bash
# Find direct secret paths
grep -r '"/run/agenix/' --include="*.nix" <files>

# Find secrets not using config.age
grep -r 'secrets/.*\.age' --include="*.nix" <files>

# Find public services without auth
grep -r 'lanOnly.*false' --include="*.nix" <files>

# Find terraform interpolation
grep -r '\$\{' --include="*.nix" packages/terraform-config/
```

## Common Secure Patterns

### Secret with Service
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "service-secret" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });

systemd.services.myservice.serviceConfig.EnvironmentFile = 
  config.age.secrets.service-secret.path;
```

### Public Service with Auth
```nix
reverseProxy = {
  enable = true;
  domains = [ "public.example.com" ];
  lanOnly = false;
  authelia = {
    enable = true;
    rules = [{ groups = [ "users" ]; policy = "two_factor"; }];
  };
};
```

### Internal Service
```nix
reverseProxy = {
  enable = true;
  domains = [ "internal.example.com" ];
  lanOnly = true;
};
```

### Terranix Resource Reference
```nix
zone_id = config.resource.cloudflare_zone.myzone "id";
storage_id = config.resource.azurerm_storage_account.mystorage "id";
```

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues.

# Related Skills

- [manage-agenix](../../secrets/manage-agenix/SKILL.md) — Secret management
- [add-service](../../nix/add-service/SKILL.md) — Service patterns
- [terraform-workflow](../../infra/terraform-workflow/SKILL.md) — Infrastructure
