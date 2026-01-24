---
name: skill-add-darwin-host
description: Bootstrap a new macOS (nix-darwin) host in the serenitea-pot flake.
tags: [darwin, macos, host]
when_to_use: User asks to add a Mac, macOS machine, or Darwin host
blast_radius: MEDIUM
---

# Add Darwin Host

Load `fact-nix` for system builders.

## Required Inputs

- [ ] **Host name** (female Genshin character)
- [ ] **Architecture**: `aarch64-darwin` (M-series) or `x86_64-darwin` (Intel)
- [ ] **Homebrew casks** (GUI apps)
- [ ] **Mac App Store apps** (requires user signed in)

## Key Difference from NixOS

| Aspect | Darwin |
|--------|--------|
| Builder | `mkDarwinSystem` |
| stateVersion | Integer (`6`), not string |
| Apps | Homebrew + nixpkgs |
| Deploy | `darwin-rebuild switch` |

## Procedure

### 1. Create Host Directory

```bash
mkdir -p hosts/darwin/<hostname>
```

### 2. Create default.nix

```nix
{ lib, ... }:
lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  system = "aarch64-darwin";  # or x86_64-darwin
  modules = [ ./system.nix ];
}
```

### 3. Create system.nix

```nix
{ pkgs, ... }:
{
  codgician = {
    system.common.enable = true;
    system.brew = {
      enable = true;
      casks = [ "iterm2" "visual-studio-code" ];
      masApps = { "Xcode" = 497799835; };
    };
    users.codgi.enable = true;
  };
  system.primaryUser = "codgi";
  system.stateVersion = 6;  # Integer, not string!
}
```

Find App Store IDs: `mas search "App Name"`

### 4. Bootstrap

**Prerequisites**: Nix and Homebrew installed. User signed into App Store.

```bash
nix build .#darwinConfigurations.<hostname>.system
./result/sw/bin/darwin-rebuild switch --flake .

# Subsequent deploys:
darwin-rebuild switch --flake .#<hostname>
```

## Exit Criteria

- [ ] Host directory with `default.nix`, `system.nix`
- [ ] `nix flake check` passes
- [ ] `darwin-rebuild switch` succeeds

**Reference**: See `hosts/darwin/furina/` (Apple Silicon), `hosts/darwin/raiden-ei/` (Intel).

**Note**: Do not commit — present changes to user.
