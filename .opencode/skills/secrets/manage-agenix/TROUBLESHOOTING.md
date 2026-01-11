# Troubleshooting: Manage Agenix

## Error: "Permission denied" accessing /run/agenix/...

### Cause 1: Host not in secrets.nix

```bash
# Check if host can access this secret
grep -A1 "my-secret.age" secrets/secrets.nix
```

**Fix**: Add host to publicKeys, then rekey:
```bash
agenix -r
```

### Cause 2: Wrong owner/group

```bash
# Check ownership
ssh <host> stat /run/agenix/my-secret

# Compare with service user
ssh <host> systemctl show myservice | grep ^User
```

**Fix**: Update in module:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "my-secret" ]
  (name: { owner = "correct-user"; group = "correct-group"; });
```

### Cause 3: Rekey needed

```bash
agenix -r
# Then rebuild and redeploy
```

---

## Error: Secret doesn't exist at /run/agenix/...

### Cause 1: Secret not registered in module

**Fix**: Add registration:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "my-secret" ]
  (name: { owner = cfg.user; group = cfg.group; });
```

### Cause 2: Host key mismatch

```bash
# Verify host key matches pubkeys.nix
ssh <host> cat /etc/ssh/ssh_host_ed25519_key.pub
# Compare with secrets/pubkeys.nix
```

### Cause 3: Impermanence issue

```bash
# Check if key persists across reboots
ssh <host> ls -la /persist/etc/ssh/
```

---

## Error: "no such identity" when running agenix

**Cause**: Your user key not available

**Fix**:
```bash
ssh-add ~/.ssh/id_ed25519

# Or specify identity
agenix -e secrets/my-secret.age -i ~/.ssh/id_ed25519
```

---

## Secret content wrong/corrupted

**Fix**: Re-edit:
```bash
agenix -e secrets/my-secret.age
# Enter correct content, save
```

---

## Secret expiry warning from chkexp

**Fix**:
1. Rotate credential at source (API provider, etc.)
2. Update secret: `agenix -e secrets/expiring-secret.age`
3. Update expiry in secrets.nix:
   ```nix
   "my-secret.age" = {
     publicKeys = someHosts [ paimon ];
     expiryDates = [ "2027-12-31" ];
   };
   ```
4. Rebuild and deploy

---

## Service can't read secret at startup

**Cause**: Secret not decrypted before service starts

**Fix**: Add dependency:
```nix
systemd.services.myservice = {
  after = [ "agenix.service" ];
  requires = [ "agenix.service" ];
};
```
