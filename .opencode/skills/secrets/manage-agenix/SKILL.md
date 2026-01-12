---
name: manage-agenix
description: Add, edit, rotate, or manage encrypted secrets using agenix.
tags: [security, secrets, agenix, encryption]
when_to_use: User needs to add, rotate, or modify secrets
blast_radius: CRITICAL
---

# Manage Agenix Secrets

## Quick Start

Secrets are encrypted `.age` files in `secrets/`. Each needs:
1. Entry in `secrets/secrets.nix` (host access)
2. Encrypted `.age` file (content)
3. Registration in module (runtime use)

## Required Inputs

- [ ] **Secret name** (e.g., `service-api-key`)
- [ ] **Which hosts need access** (use pubkeys.nix groups)
- [ ] **Secret content**
- [ ] **Where used** (which module/service)

## Safety Rules

- ❌ **NEVER** reference secrets directly - use `config.age.secrets.<name>.path`
- ❌ **NEVER** commit plaintext secrets
- ❌ **NEVER** include secrets in ISO builds
- ⚠️ **ALWAYS** verify owner/group/mode match service user

---

# Procedure: Add Secret

## Phase 1: Define in secrets.nix

```nix
# secrets/secrets.nix
let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys; with pubKeys.hosts;
{
  # Simple host list
  "my-secret.age".publicKeys = someHosts [ paimon fischl ];
  
  # With expiry date
  "expiring-secret.age" = {
    publicKeys = someHosts [ paimon ];
    expiryDates = [ "2026-12-31" ];
  };
}
```

### Access Groups

| Group | Use Case |
|-------|----------|
| `allHosts` | User passwords, shared configs |
| `allServers` | Service credentials |
| `privateServers` | Internal services |
| `publicServers` | Internet-facing services |
| `someHosts [x y]` | Specific hosts |

## Phase 2: Create Secret

```bash
agenix -e secrets/my-secret.age
```

**Environment file format**:
```
API_KEY=sk-abc123
DATABASE_URL=postgresql://user:pass@host/db
```

## Phase 3: Register in Module

```nix
config = lib.mkIf cfg.enable {
  # Register with agenix
  codgician.system.agenix.secrets = lib.genAttrs
    [ "my-secret" ]
    (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });
  
  # Use in service
  systemd.services.myservice.serviceConfig.EnvironmentFile = 
    config.age.secrets."my-secret".path;
};
```

## Phase 4: Validate

```bash
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# Deploy and verify
ssh <host> ls -la /run/agenix/my-secret
ssh <host> stat /run/agenix/my-secret
```

---

# Procedure: Rotate Secret (User Approval Required)

⚠️ **STOP**: Rotating secrets and deploying requires user approval.

```bash
# Edit with new value
agenix -e secrets/my-secret.age

# Rebuild affected hosts (requires approval)
nixos-rebuild switch --flake .#<host> ...

# Verify service works
ssh <host> systemctl status <service>
```

---

# Procedure: Rekey All Secrets (User Approval Required)

When to rekey: Added/removed host from pubkeys.nix, changed access groups.

⚠️ **STOP**: Rekeying re-encrypts all secrets. Ask user before proceeding.

```bash
agenix -r
```

---

# Exit Criteria

- [ ] Entry in `secrets/secrets.nix`
- [ ] `.age` file created
- [ ] Secret registered in module
- [ ] Configuration builds
- [ ] Secret at `/run/agenix/<name>` with correct permissions
- [ ] Service reads secret successfully

---

# Commit (User Approval Required)

First, format all code:
```bash
nix fmt
```

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- secrets/secrets.nix (modified)
- secrets/<name>.age (new)
- modules/.../default.nix (modified)

Proposed: `secrets: add <name> for <service>`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

# Examples

## Example 1: Service API Key

**secrets/secrets.nix**:
```nix
"grafana-api-key.age".publicKeys = someHosts [ paimon ];
```

**Module registration**:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "grafana-api-key" ]
  (name: { owner = "grafana"; group = "grafana"; mode = "0600"; });
```

**Usage**:
```nix
services.grafana.settings.security.admin_password = 
  "$__file{${config.age.secrets."grafana-api-key".path}}";
```

## Example 2: Environment File (Multiple Secrets)

**Create**:
```bash
agenix -e secrets/myservice-env.age
```

**Content**:
```
DATABASE_URL=postgresql://user:pass@localhost/db
API_KEY=sk-abc123
SECRET_TOKEN=xyz789
```

**secrets.nix**:
```nix
"myservice-env.age".publicKeys = someHosts [ paimon ];
```

**Module**:
```nix
systemd.services.myservice.serviceConfig.EnvironmentFile = 
  config.age.secrets."myservice-env".path;
```

## Example 3: Expiring Credential

```nix
# secrets/secrets.nix
"oauth-token.age" = {
  publicKeys = allServers;
  expiryDates = [ "2026-06-15" ];  # chkexp warns before this
};
```

Check expiry with: `nix run .#chkexp`

## Example 4: WireGuard Private Key

**secrets.nix**:
```nix
"wg-private-key-myhost.age".publicKeys = someHosts [ myhost ];
```

**Module registration**:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "wg-private-key-myhost" ]
  (name: { owner = "root"; group = "root"; mode = "0600"; });
```

**Usage**:
```nix
networking.wireguard.interfaces.wg0 = {
  privateKeyFile = config.age.secrets."wg-private-key-myhost".path;
};
```

## Access Group Reference

```nix
# secrets/pubkeys.nix
rec {
  users = {
    codgi = [ "ssh-ed25519 AAAA..." ];
  };
  
  hosts = {
    paimon = [ "ssh-ed25519 AAAA..." ];
    fischl = [ "ssh-ed25519 AAAA..." ];
    lumine = [ "ssh-ed25519 AAAA..." ];
  };
  
  # Computed groups
  allHosts = builtins.concatLists (builtins.attrValues hosts) ++ users.codgi;
  allServers = hosts.paimon ++ hosts.fischl ++ hosts.lumine ++ users.codgi;
  privateServers = hosts.paimon ++ hosts.fischl ++ users.codgi;
  publicServers = hosts.lumine ++ hosts.xianyun ++ users.codgi;
  
  # Helper
  someHosts = hostList: builtins.concatLists hostList ++ users.codgi;
}
```

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [security-review](../../review/security-review/SKILL.md) — Audit before commit
- [add-nixos-host](../../nix/add-nixos-host/SKILL.md) — New hosts need pubkey
- [add-service](../../nix/add-service/SKILL.md) — Services need secrets
