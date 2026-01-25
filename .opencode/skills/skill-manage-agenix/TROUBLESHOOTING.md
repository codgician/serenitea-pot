# Troubleshooting: Manage Agenix

> See AGENTS.md for global troubleshooting principles.

## "Permission denied" accessing /run/agenix/...

### Cause 1: Host not in secrets.nix

**Diagnosis**: `grep -A1 "my-secret.age" secrets/secrets.nix`

**Fix**: Add host to `publicKeys`, then rekey (`agenix -r` requires user approval).

### Cause 2: Wrong owner/group

**Diagnosis**:
```bash
ssh <host> stat /run/agenix/my-secret
ssh <host> systemctl show myservice | grep ^User
```

**Fix**:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "my-secret" ]
  (name: { owner = "correct-user"; group = "correct-group"; });
```

### Cause 3: Rekey needed after pubkeys.nix change

`agenix -r` requires user approval per AGENTS.md principles.

---

## Secret doesn't exist at /run/agenix/...

### Cause 1: Not registered in module

**Fix**:
```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "my-secret" ]
  (name: { owner = cfg.user; group = cfg.group; });
```

### Cause 2: Host key mismatch

Compare `ssh <host> cat /etc/ssh/ssh_host_ed25519_key.pub` with `secrets/pubkeys.nix`.

### Cause 3: Impermanence issue

Check `/persist/etc/ssh/` has the host key.

---

## "no such identity" when running agenix

**Cause**: SSH identity not available

**Action**: Ask user to ensure their key is loaded or specify identity path.

---

## Secret content wrong/corrupted

`agenix -e` requires user approval per AGENTS.md principles.

---

## Secret expiry warning from chkexp

**User-driven workflow**:
1. Report expiry to user
2. User rotates credential at source
3. Ask approval to update secret (`agenix -e`)
4. Ask approval to rebuild/deploy

---

## Service can't read secret at startup

**Fix**: Add dependency:
```nix
systemd.services.myservice = {
  after = [ "agenix.service" ];
  requires = [ "agenix.service" ];
};
```
