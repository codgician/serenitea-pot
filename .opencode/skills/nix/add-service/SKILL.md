---
name: add-service
description: Create a new NixOS service module following serenitea-pot conventions.
tags: [nixos, service, module, reverse-proxy]
when_to_use: User asks to add, implement, or create a service module
blast_radius: MEDIUM
---

# Add NixOS Service Module

## Quick Start

Create module at `modules/nixos/services/<name>/default.nix` using `lib.codgician` helpers.

## Required Inputs

- [ ] **Service name** (lowercase, hyphenated)
- [ ] **Package name** in nixpkgs (or custom derivation)
- [ ] **Listen port**
- [ ] **Needs reverse proxy?**
- [ ] **Needs secrets?**
- [ ] **Needs persistence?**

## Module Location

```
modules/nixos/services/<service-name>/default.nix
```

Auto-discovered via `lib.codgician.getFolderPaths`.

---

# Procedure

## Phase 1: Create Module File

```bash
mkdir -p modules/nixos/services/<service-name>
touch modules/nixos/services/<service-name>/default.nix
```

## Phase 2: Implement Module

### Pattern A: Wrap Existing NixOS Service

Use when NixOS already has a service module (jellyfin, grafana, etc.):

```nix
{ config, lib, pkgs, ... }:

let
  serviceName = "jellyfin";
  cfg = config.codgician.services.${serviceName};
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "Jellyfin";
    user = lib.mkOption { type = lib.types.str; default = serviceName; };
    group = lib.mkOption { type = lib.types.str; default = serviceName; };
    dataDir = lib.mkOption { type = lib.types.path; default = "/var/lib/${serviceName}"; };
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:8096";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.${serviceName} = {
        enable = true;
        inherit (cfg) user group;
      };
      codgician.system.impermanence.extraItems =
        lib.mkIf (cfg.dataDir == "/var/lib/${serviceName}")
          [{ type = "directory"; path = cfg.dataDir; inherit (cfg) user group; }];
    })
    (lib.codgician.mkServiceReverseProxyConfig { inherit serviceName cfg; })
  ];
}
```

### Pattern B: Custom Systemd Service

Use for new services without NixOS module:

```nix
{ config, lib, pkgs, ... }:

let
  serviceName = "<name>";
  cfg = config.codgician.services.${serviceName};
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "Service";
    package = lib.mkPackageOption pkgs "<pkg>" { };
    user = lib.mkOption { type = lib.types.str; default = serviceName; };
    group = lib.mkOption { type = lib.types.str; default = serviceName; };
    port = lib.mkOption { type = lib.types.port; default = 8080; };
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:8080";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.users.${cfg.user} = { isSystemUser = true; group = cfg.group; };
      users.groups.${cfg.group} = { };

      systemd.services.${serviceName} = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = cfg.user;
          ExecStart = "${cfg.package}/bin/${serviceName} --port ${toString cfg.port}";
          Restart = "on-failure";
        };
      };
    })
    (lib.codgician.mkServiceReverseProxyConfig { inherit serviceName cfg; })
  ];
}
```

## Phase 3: Enable in Host

```nix
# hosts/nixos/<host>/system.nix
codgician.services.<name> = {
  enable = true;
  reverseProxy = {
    enable = true;
    domains = [ "<name>.codgician.me" ];
    authelia.enable = true;  # For public services
    # lanOnly = true;        # For internal only
  };
};
```

## Phase 4: Add Secrets (If Needed)

See [manage-agenix](../../secrets/manage-agenix/SKILL.md).

## Phase 5: Add DNS (If Public)

See [terraform-workflow](../../infra/terraform-workflow/SKILL.md).

## Phase 6: Validate

```bash
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo
ssh <host> systemctl status <service>
curl -I https://<service>.codgician.me
```

---

# Exit Criteria

- [ ] Module at `modules/nixos/services/<name>/default.nix`
- [ ] Options under `options.codgician.services.<name>`
- [ ] Enabled in host config
- [ ] Configuration builds
- [ ] Service starts: `systemctl status`
- [ ] Reverse proxy works (if applicable)
- [ ] Secrets decrypt (if applicable)

---

# Commit (User Approval Required)

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- modules/nixos/services/<name>/default.nix (new)
- hosts/nixos/<host>/system.nix (modified)

Proposed: `<name>: init module`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

# Examples

## Example 1: Reference Implementations

| Pattern | Example | Notes |
|---------|---------|-------|
| Wrapper | `modules/nixos/services/jellyfin/` | Wraps NixOS service |
| Database | `modules/nixos/services/open-webui/` | PostgreSQL integration |
| Container | `modules/nixos/services/comfyui/` | OCI with GPU passthrough |

## Example 2: Host Configuration

```nix
# hosts/nixos/paimon/system.nix
{
  codgician.services = {
    jellyfin = {
      enable = true;
      reverseProxy = {
        enable = true;
        domains = [ "jellyfin.codgician.me" ];
        lanOnly = true;  # Internal only
      };
    };
    
    grafana = {
      enable = true;
      reverseProxy = {
        enable = true;
        domains = [ "grafana.codgician.me" ];
        authelia = {
          enable = true;  # Public with auth
          rules = [{ groups = [ "admins" ]; policy = "two_factor"; }];
        };
      };
    };
  };
}
```

## Example 3: Service with Secrets

```nix
{ config, lib, pkgs, ... }:

let
  serviceName = "myapi";
  cfg = config.codgician.services.${serviceName};
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "My API";
    user = lib.mkOption { type = lib.types.str; default = serviceName; };
    group = lib.mkOption { type = lib.types.str; default = serviceName; };
  };

  config = lib.mkIf cfg.enable {
    # Register secret
    codgician.system.agenix.secrets = lib.genAttrs
      [ "${serviceName}-env" ]
      (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });

    # Use in service
    systemd.services.${serviceName}.serviceConfig.EnvironmentFile = 
      config.age.secrets."${serviceName}-env".path;
  };
}
```

## Reverse Proxy Options Reference

```nix
reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
  serviceName = "myservice";
  defaultProxyPass = "http://127.0.0.1:8080";
};
```

Generated options:
- `reverseProxy.enable` - Enable nginx vhost
- `reverseProxy.domains` - List of domains
- `reverseProxy.lanOnly` - Restrict to LAN
- `reverseProxy.authelia.enable` - Add Authelia protection
- `reverseProxy.authelia.rules` - Access rules

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [manage-agenix](../../secrets/manage-agenix/SKILL.md) — Secrets
- [security-review](../../review/security-review/SKILL.md) — Before commit
- [terraform-workflow](../../infra/terraform-workflow/SKILL.md) — DNS records
- [build-deploy](../build-deploy/SKILL.md) — Deployment
