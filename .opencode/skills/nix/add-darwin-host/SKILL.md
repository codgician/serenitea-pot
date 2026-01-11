---
name: add-darwin-host
description: Bootstrap a new macOS (nix-darwin) host in the serenitea-pot flake.
tags: [darwin, macos, host, bootstrap, homebrew]
when_to_use: User asks to add a Mac, macOS machine, or Darwin host
blast_radius: MEDIUM
---

# Add Darwin Host

## Quick Start

Create host at `hosts/darwin/<name>/` using `lib.codgician.mkDarwinSystem`.

## Required Inputs

- [ ] **Host name** (female Genshin character)
- [ ] **System architecture**: `aarch64-darwin` (M-series) or `x86_64-darwin` (Intel)
- [ ] **Homebrew apps** (casks and Mac App Store apps)
- [ ] **User account name** (typically `codgi`)

## Naming Rules

| Architecture | Name After | Examples |
|--------------|------------|----------|
| aarch64 (M-series) | Fontaine/Descenders | furina |
| x86_64 (Intel) | Female characters | raiden-ei |

## Darwin vs NixOS Differences

| Aspect | NixOS | Darwin |
|--------|-------|--------|
| Builder | `mkNixosSystem` | `mkDarwinSystem` |
| Disk management | Disko | None |
| Hardware config | `hardware.nix` | Not needed |
| App management | nixpkgs only | Homebrew + nixpkgs |
| Deploy | `nixos-rebuild` | `darwin-rebuild` |
| stateVersion | String (`"25.11"`) | Integer (`6`) |

---

# Procedure

## Phase 1: Create Directory

```bash
mkdir -p hosts/darwin/<hostname>
```

## Phase 2: Create Files

### default.nix (Required)

```nix
{ lib, ... }:

lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  system = "aarch64-darwin";  # or x86_64-darwin
  modules = [ ./system.nix ];
}
```

### system.nix (Required)

```nix
{ pkgs, ... }:

{
  codgician = {
    system = {
      common.enable = true;
      brew = {
        enable = true;
        casks = (import ./brew.nix).casks;
        masApps = (import ./brew.nix).masApps;
      };
    };
    users.codgi.enable = true;
  };

  system.primaryUser = "codgi";

  home-manager.users.codgi = { pkgs, ... }: {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      zsh.enable = true;
    };
    home.stateVersion = "25.11";
  };

  # Darwin: stateVersion is INTEGER, not string
  system.stateVersion = 6;
}
```

### brew.nix (Optional)

```nix
{
  masApps = {
    "Xcode" = 497799835;
  };
  casks = [
    "appcleaner"
    "microsoft-edge"
  ];
}
```

Find App Store IDs: `mas search "App Name"` or `mas list`

## Phase 3: Register Host Key (If Secrets Needed)

```bash
# Get host key
cat /etc/ssh/ssh_host_ed25519_key.pub

# Add to secrets/pubkeys.nix
# Rekey: agenix -r
```

## Phase 4: Bootstrap

```bash
# Install Nix (if needed)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Build
nix build .#darwinConfigurations.<hostname>.system

# First apply (bootstrap)
./result/sw/bin/darwin-rebuild switch --flake .

# Subsequent deploys
darwin-rebuild switch --flake .#<hostname>
```

## Phase 5: Verify

```bash
darwin-rebuild --list-generations
brew list --cask
mas list
```

---

# Examples

## Complete Darwin Host (furina)

```
hosts/darwin/furina/
├── default.nix
├── system.nix
└── brew.nix
```

**brew.nix** with custom taps:
```nix
{
  masApps = {
    "Xcode" = 497799835;
    "Microsoft Word" = 462054704;
  };
  casks = [
    "appcleaner"
    "microsoft-edge"
    "visual-studio-code"
    "iterm2"
    "docker"
  ];
}
```

**system.nix** with custom taps:
```nix
codgician.system.brew = {
  enable = true;
  taps = [ "playcover/playcover" ];
  casks = (import ./brew.nix).casks;
  masApps = (import ./brew.nix).masApps;
};
```

## Common Casks

```nix
casks = [
  # Browsers
  "microsoft-edge" "google-chrome" "firefox"
  # Development
  "visual-studio-code" "iterm2" "docker"
  # Utilities
  "appcleaner" "rectangle" "stats"
];
```

## Reference Hosts

| Arch | Host | See |
|------|------|-----|
| aarch64 | furina | `hosts/darwin/furina/` |
| x86_64 | raiden-ei | `hosts/darwin/raiden-ei/` |

---

# Exit Criteria

- [ ] Host directory: `hosts/darwin/<hostname>/`
- [ ] Files: `default.nix`, `system.nix`
- [ ] `nix build` succeeds
- [ ] `darwin-rebuild switch` succeeds
- [ ] Homebrew apps installed
- [ ] Home Manager applied

---

# Commit (User Approval Required)

⚠️ **STOP**: Present changes to user for review.

```
Ready to commit:
- hosts/darwin/<hostname>/ (new)
- secrets/pubkeys.nix (if modified)

Proposed: `<hostname>: init darwin host`

Shall I commit and push?
```

**Wait for approval before `git commit` and `git push`.**

---

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for error recovery.

# Related Skills

- [add-nixos-host](../add-nixos-host/SKILL.md) — NixOS hosts
- [manage-agenix](../../secrets/manage-agenix/SKILL.md) — Secrets
- [build-deploy](../build-deploy/SKILL.md) — Deployment
