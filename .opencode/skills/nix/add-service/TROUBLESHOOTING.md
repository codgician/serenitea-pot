# Troubleshooting: Add Service

## Error: "attribute 'codgician' not found"

**Cause**: Module not properly structured

**Check**:
- Module is in `modules/nixos/services/<name>/default.nix`
- File has correct structure (let/in with options and config)

See [debug-eval](../debug-eval/SKILL.md) for diagnosis.

---

## Service fails to start

**Check logs**:
```bash
ssh <host> journalctl -u <service> -f
```

**Common causes**:
1. **Port in use**: Check with `ss -tlnp | grep <port>`
2. **Permission denied**: Check user/group ownership
3. **Missing secret**: Check agenix registration

---

## Error: 502 Bad Gateway (reverse proxy)

**Causes**:
1. Service not listening on expected port
2. Wrong proxyPass URL
3. Service not started

**Debug**:
```bash
ssh <host> ss -tlnp | grep <port>
ssh <host> systemctl status <service>
```

---

## Secret permission denied

**Fix**: Ensure ownership matches service user:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "my-secret" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });
```

---

## Module options don't appear

**Cause**: Syntax error preventing evaluation

**Debug**:
```bash
nix repl
:lf .
nixosConfigurations.<host>.config.codgician.services.<name>
```

---

## Reverse proxy not applying

**Check**:
1. `reverseProxy.enable = true` is set
2. `reverseProxy.domains` is not empty
3. DNS record exists (if public)

```bash
ssh <host> nginx -t
ssh <host> systemctl status nginx
```

---

## Data not persisting (impermanence)

**Fix**: Register data directory:
```nix
codgician.system.impermanence.extraItems = [
  { type = "directory"; path = cfg.dataDir; inherit (cfg) user group; }
];
```
