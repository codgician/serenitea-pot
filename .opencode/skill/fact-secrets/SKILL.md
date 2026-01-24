---
name: fact-secrets
description: Secrets domain knowledge - Agenix structure, access groups, and patterns
---

# Secrets Domain Knowledge

## Directory Layout

```
secrets/
├── secrets.nix      # Secret definitions (which hosts can access)
├── pubkeys.nix      # Public keys and access groups
└── *.age            # Encrypted secret files
```

## Access Groups

| Group | Hosts | Use Case |
|-------|-------|----------|
| `allHosts` | All hosts + user | User passwords |
| `allServers` | paimon, fischl, lumine, xianyun + user | Service credentials |
| `privateServers` | paimon, fischl + user | Internal services |
| `publicServers` | lumine, xianyun + user | Internet-facing |
| `someHosts [...]` | Specified + user | Specific hosts |

## secrets.nix Format

```nix
let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys;
with pubKeys.hosts;
{
  # Simple
  "myservice-env.age".publicKeys = someHosts [ paimon ];
  
  # With expiry
  "oauth-token.age" = {
    publicKeys = allServers;
    expiryDates = [ "2026-12-31" ];
  };
}
```

## Secret Content Formats

**Environment file** (most common):
```
API_KEY=sk-abc123
DATABASE_URL=postgresql://user:pass@host/db
```

**Single value**:
```
mysecretpassword
```

## Commands

| Command | Purpose |
|---------|---------|
| `agenix -e secrets/<name>.age` | Edit/create secret |
| `agenix -r` | Rekey all (after pubkey changes) |
| `nix run .#chkexp` | Check expiring secrets |

## Usage in Modules

**Register secret**:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "myservice-env" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });
```

**Reference in service**:
```nix
systemd.services.myservice.serviceConfig.EnvironmentFile = 
  config.age.secrets."myservice-env".path;
```

## Critical Rules

- **Always use**: `config.age.secrets.<name>.path`
- **Never hardcode**: `"/run/agenix/<name>"`
- Secrets decrypt to `/run/agenix/` at runtime
