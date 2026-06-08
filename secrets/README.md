# 🔑 Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and
[age](https://github.com/FiloSottile/age). The flake's `secrets` app wraps the
dangerous sops steps so they stay atomic; never edit `.sops.yaml` or the
encrypted files by hand.

- `secrets.nix` — the registry: every secret, its recipients, and metadata.
- `pubkeys.nix` — SSH public keys and host/group aliases (the key registry).
- `values/<name>` — the encrypted files (one opaque sops blob per secret).
- `templates/<name>.nix` — env-bundle render recipes (never encrypted).
- `.sops.yaml` — **generated**; recipients per file. Do not edit by hand.

## Add or rotate a secret

1. Declare it in `secrets.nix` with its recipients (a host/group alias from
   `pubkeys.nix`, or leave the recipients to a referencing template).

1. Create or edit its encrypted value:

   ```bash
   nix run .#secrets -- edit <name>
   ```

   This opens `$EDITOR` via sops, regenerating `.sops.yaml` first if needed, and
   `git add`s the result. Plaintext only ever lives in the editor buffer.

## Re-key after changing recipients

Whenever you change `pubkeys.nix` or a secret's recipients (e.g. adding a host),
regenerate `.sops.yaml` and re-encrypt every managed file to match:

```bash
nix run .#secrets -- rekey
```

## Verify (CI-safe, no decryption)

Assert every encrypted file's recipients match the registry:

```bash
nix run .#secrets -- check
```

## Other commands

- `nix run .#secrets -- render <template>` — render an env-bundle template to a
  `0600` tmpfs file and print its path (operator-side activation).
- `nix run .#secrets -- for` — list the managed secrets.

See [`docs/secrets-design.md`](../docs/secrets-design.md) for the full design.
