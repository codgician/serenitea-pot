# Troubleshooting: Security Review

## "Permission denied" on secret at runtime

**Symptom**: Eval succeeds, deploy succeeds, service fails

**Causes & Fixes**:

### Host pubkey not in secrets/pubkeys.nix
```bash
grep <hostname> secrets/pubkeys.nix
# Fix: Add to allHosts, then rekey
agenix -r
```

### Secret owner/group mismatch
```bash
ssh <host> stat /run/agenix/<secret>
ssh <host> systemctl show <service> | grep ^User
# Fix: Update owner in codgician.system.agenix.secrets
```

### Impermanence identity path wrong
```bash
ssh <host> ls -la /etc/ssh/ssh_host_ed25519_key
ssh <host> ls -la /persist/etc/ssh/
```

---

## Nginx 502 Bad Gateway

**Causes**:

### Service not listening
```bash
ssh <host> systemctl status <service>
ssh <host> ss -tlnp | grep <port>
```

### Wrong port in reverseProxy
Check `reverseProxy.localPort` matches service's listen port

### Firewall blocking
```bash
ssh <host> iptables -L -n | grep <port>
```

---

## Terraform state drift

```bash
# Refresh state
nix run .#tfmgr -- shell
terraform refresh
exit

# Check specific resource
terraform state show <resource>

# Import if manually created
terraform import <resource_type>.<name> <id>
```

---

## Public service without auth detected

**Risk**: Unauthorized access to internal service

**Fix options**:
1. Add Authelia: `authelia.enable = true`
2. Make internal: `lanOnly = true`
3. Document exception if intentionally public

---

## Direct secret path found

**Pattern detected**:
```nix
"/run/agenix/my-secret"  # BAD
```

**Fix**:
```nix
config.age.secrets.my-secret.path  # GOOD
```

---

## Terraform interpolation found

**Pattern detected**:
```nix
"${azurerm_storage.X.id}"  # BAD
```

**Fix**:
```nix
config.resource.azurerm_storage.X "id"  # GOOD
```
