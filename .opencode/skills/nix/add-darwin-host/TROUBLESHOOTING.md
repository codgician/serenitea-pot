# Troubleshooting: Add Darwin Host

> See AGENTS.md for global troubleshooting principles.

## "could not find any previously installed nix-darwin"

**Cause**: First-time installation needs bootstrap

**Fix**:
```bash
nix build .#darwinConfigurations.<hostname>.system
./result/sw/bin/darwin-rebuild switch --flake .
```

---

## "Homebrew not found"

**Cause**: Homebrew not installed

**Action**: Ask user to install Homebrew (requires running external script).

After installed, manage packages via nix-darwin:
```nix
homebrew = {
  enable = true;
  brews = [ "mas" ];
};
```

---

## "mas: command not found"

**Fix (Nix way)**: Add to nix-darwin config:
```nix
homebrew.brews = [ "mas" ];
```

---

## App Store app installation fails

**Causes**: Not signed into App Store, app not purchased

**Action**: Ask user to sign in and purchase/download manually first.

---

## "attribute 'codgician' not found"

**Cause**: Not using `lib.codgician.mkDarwinSystem`

**Fix**: Ensure `default.nix` uses:
```nix
lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
}
```

---

## stateVersion type error

**Cause**: Using string instead of integer

**Wrong**: `system.stateVersion = "25.11";`
**Correct**: `system.stateVersion = 6;` (Darwin uses integer)

Note: `home.stateVersion` still uses string format.

---

## Secret/agenix errors

See [manage-agenix/TROUBLESHOOTING.md](../../secrets/manage-agenix/TROUBLESHOOTING.md)
