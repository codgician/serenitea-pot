---
name: skill-add-service
description: Create a new NixOS service module following serenitea-pot conventions.
tags: [nixos, service, module]
when_to_use: User asks to add, implement, or create a service module
blast_radius: MEDIUM
---

# Add NixOS Service Module

Load `fact-nix` for module templates and `fact-secrets` if secrets needed.

## Required Inputs

- [ ] **Service name** (lowercase, hyphenated)
- [ ] **Package** in nixpkgs or custom derivation
- [ ] **Listen port**
- [ ] **Needs reverse proxy?** (usually yes)
- [ ] **Needs secrets?** (API keys, passwords)
- [ ] **Needs persistence?** (data directory)

## Procedure

### 1. Create Module

```bash
mkdir -p modules/nixos/services/<name>
```

Create `default.nix` using the template from `fact-nix` → "Standard Service Module".

**Key decisions:**
- If NixOS has `services.<name>` → wrap it (set `services.<name>.enable = true` inside)
- If no NixOS module → create custom systemd service

### 2. Enable in Host

```nix
# hosts/nixos/<host>/system.nix
codgician.services.<name> = {
  enable = true;
  reverseProxy = {
    enable = true;
    domains = [ "<name>.codgician.me" ];
    lanOnly = true;  # or authelia.enable = true for public
  };
};
```

### 3. Add Secrets (if needed)

See `fact-secrets` for patterns. Register in module:

```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "<name>-env" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });
```

### 4. Add DNS (if public)

See `skill-terraform-workflow`.

### 5. Validate

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

## Exit Criteria

- [ ] Module at `modules/nixos/services/<name>/default.nix`
- [ ] Uses `options.codgician.services.<name>` namespace
- [ ] Enabled in host config
- [ ] `nix flake check` passes
- [ ] `nix fmt` clean

**Reference**: See `modules/nixos/services/jellyfin/` for wrapper pattern, `modules/nixos/services/open-webui/` for database integration.

**Note**: Do not commit — present changes to user.
