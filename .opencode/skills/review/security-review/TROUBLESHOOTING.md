# Troubleshooting: Security Review

> See AGENTS.md for global troubleshooting principles.

## "Permission denied" on secret at runtime

**Symptom**: Eval succeeds, deploy succeeds, service fails

### Host pubkey missing

**Diagnosis**: `grep <hostname> secrets/pubkeys.nix`

**Fix**: Add key, then `agenix -r` (requires user approval).

### Owner/group mismatch

**Diagnosis**:
```bash
ssh <host> stat /run/agenix/<secret>
ssh <host> systemctl show <service> | grep ^User
```

**Fix**: Update `codgician.system.agenix.secrets`

### Impermanence identity path wrong

Check `/persist/etc/ssh/` has host key.

---

## Nginx 502 Bad Gateway

| Cause | Check |
|-------|-------|
| Service not listening | `systemctl status <service>` |
| Wrong port | `reverseProxy.localPort` matches service |
| Firewall | `networking.firewall.allowedTCPPorts` |

---

## Terraform state drift

All terraform operations inside `tfmgr shell`. State mutations require user approval.

---

## Public service without auth detected

**Fix options** (present to user):
1. Add Authelia: `authelia.enable = true`
2. Make internal: `lanOnly = true`
3. Document exception (user must confirm)

---

## Direct secret path found

**Bad**: `"/run/agenix/my-secret"`
**Good**: `config.age.secrets.my-secret.path`

---

## Terraform interpolation found

**Bad**: `"${azurerm_storage.X.id}"`
**Good**: `config.resource.azurerm_storage.X "id"`
