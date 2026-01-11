# Troubleshooting: Add Darwin Host

## Error: "could not find any previously installed nix-darwin"

**Cause**: First-time installation needs bootstrap

**Fix**: Use the built `darwin-rebuild`:
```bash
nix build .#darwinConfigurations.<hostname>.system
./result/sw/bin/darwin-rebuild switch --flake .
```

---

## Error: "Homebrew not found"

**Cause**: Homebrew not installed

**Fix**:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## Error: "mas: command not found"

**Cause**: `mas` (Mac App Store CLI) not installed

**Fix**:
```bash
brew install mas
```

---

## Error: App Store app installation fails

**Causes**:
1. Not signed into App Store
2. App not purchased

**Fix**:
1. Sign into Mac App Store app
2. Purchase/download manually first if needed
3. Verify App ID: `mas search "App Name"`

---

## Error: "attribute 'codgician' not found"

**Cause**: Not using `lib.codgician.mkDarwinSystem`

**Fix**: Ensure `default.nix` uses:
```nix
lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  # ...
}
```

See [debug-eval](../debug-eval/SKILL.md) for details.

---

## Secrets don't decrypt

**Causes**:
1. Host key not in `secrets/pubkeys.nix`
2. Wrong key path

**Fix**:
```bash
# Verify host key exists
ls -la /etc/ssh/ssh_host_ed25519_key

# Check pubkeys.nix has the key
grep <hostname> secrets/pubkeys.nix

# Rekey if needed
agenix -r
```

---

## Error: stateVersion type error

**Cause**: Using string instead of integer

**Wrong**:
```nix
system.stateVersion = "25.11";  # Wrong for Darwin!
```

**Correct**:
```nix
system.stateVersion = 6;  # Darwin uses integer
```

Note: `home.stateVersion` still uses string format.
