---
name: skill-manage-agenix
description: Add, edit, rotate, or manage encrypted secrets using agenix.
tags: [security, secrets, agenix]
when_to_use: User needs to add, rotate, or modify secrets
blast_radius: CRITICAL
---

# Manage Agenix Secrets

Load `fact-secrets` for access groups and patterns.

## Required Inputs

- [ ] **Secret name** (e.g., `myservice-env`)
- [ ] **Which hosts need access** (see `fact-secrets` for groups)
- [ ] **Secret content** (env file or single value)
- [ ] **Consuming service** (determines owner/group)

## Safety Rules

- ❌ **NEVER** reference `/run/agenix/...` directly — use `config.age.secrets.<name>.path`
- ❌ **NEVER** commit plaintext secrets
- ⚠️ **ALWAYS** verify owner/group/mode match service user

## Procedure: Add Secret

### 1. Define in secrets.nix

```nix
# secrets/secrets.nix
"myservice-env.age".publicKeys = someHosts [ paimon ];

# With expiry:
"token.age" = {
  publicKeys = allServers;
  expiryDates = [ "2026-12-31" ];
};
```

### 2. Create Encrypted File

```bash
agenix -e secrets/myservice-env.age
```

Content (env file format):
```
API_KEY=sk-abc123
DATABASE_URL=postgresql://...
```

### 3. Register in Module

```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "myservice-env" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });

systemd.services.myservice.serviceConfig.EnvironmentFile = 
  config.age.secrets."myservice-env".path;
```

### 4. Validate

```bash
nix flake check
ssh <host> stat /run/agenix/myservice-env
```

## Procedure: Rekey (User Approval Required)

When host pubkeys change:

```bash
agenix -r  # Re-encrypts all secrets
```

## Exit Criteria

- [ ] Entry in `secrets/secrets.nix`
- [ ] `.age` file created
- [ ] Registered in consuming module
- [ ] `nix flake check` passes
- [ ] Secret decrypts with correct permissions

**Reference**: See `secrets/secrets.nix` for existing patterns.

**Note**: Do not commit — present changes to user.
