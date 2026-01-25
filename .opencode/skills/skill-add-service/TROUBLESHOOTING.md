# Troubleshooting: Add Service

> See AGENTS.md for global troubleshooting principles.

## "attribute 'codgician' not found"

**Cause**: Module not properly structured

**Check**:
- Module is in `modules/nixos/services/<name>/default.nix`
- File has correct structure (let/in with options and config)

See [debug-eval](../skill-debug-eval/SKILL.md) for diagnosis.

---

## Service fails to start

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `ExecStart` fails | Package/command issue | Check `cfg.package` |
| "Permission denied" | Wrong owner/group | Update `codgician.system.agenix.secrets` |
| "Address in use" | Port conflict | Check `cfg.port` |
| Secret not found | Missing registration | Add to `codgician.system.agenix.secrets` |

---

## 502 Bad Gateway (reverse proxy)

**Repo-specific causes**:
1. Service not listening on port specified in `reverseProxy.proxyPass`
2. `mkServiceReverseProxyConfig` not in `lib.mkMerge`
3. Service not started

**Check structure**:
```nix
config = lib.mkMerge [
  (lib.mkIf cfg.enable { /* service */ })
  (lib.codgician.mkServiceReverseProxyConfig { inherit serviceName cfg; })
];
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

## Data not persisting (impermanence)

**Fix**:
```nix
codgician.system.impermanence.extraItems = [
  { type = "directory"; path = cfg.dataDir; inherit (cfg) user group; }
];
```

---

## Secret errors

See [manage-agenix/TROUBLESHOOTING.md](../skill-manage-agenix/TROUBLESHOOTING.md)
