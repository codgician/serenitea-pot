# Secrets

Secrets use native SOPS documents and sops-nix:

- `secrets.nix`: per-secret host/user access and expiry metadata.
- `pubkeys.nix`: SSH public keys used to construct typed recipient records.
- `data/*.json`: encrypted SOPS documents.
- `.sops.yaml`: generated SOPS creation rules.
- `templates/*.nix`: per-file native sops-nix templates.

Hosts decrypt with their SSH host private key. User records grant operator
decryption without deploying the secret to a system.

## Add a secret

Declare it first:

```nix
example = {
  hosts = with hosts; [ paimon ];
  users = with users; [ codgi ];
  expires = "2027-01-01"; # optional
};
```

`hosts` and `users` both default to an empty list. Omit a field instead of
declaring an explicit empty list. At least one recipient is required:

```nix
# Operator-only: not deployed to any host.
operator-secret = {
  users = with users; [ codgi ];
};

# Host-only: operators cannot decrypt it directly.
host-secret = {
  hosts = with hosts; [ paimon ];
};
```

Then stage the declaration so the flake sees it and create the document:

```bash
git add secrets/secrets.nix
nix run .#secrets -- create example
```

New secrets use `data/<name>.json`. Templates use `ref "<name>"` directly in
their content; dependencies are discovered automatically.

## Change access

Edit `hosts` or `users`, stage the declaration, then generate and review the
SOPS rules:

```bash
git add secrets/secrets.nix
nix run .#secrets -- sync
git diff --cached -- secrets/.sops.yaml
```

Run `nix run .#secrets -- rekey` after approval. `sync` alone does not revoke an
old recipient because the document still contains its wrapped data key.

## Edit and verify

```bash
nix run .#secrets -- edit example
nix run .#secrets -- check
```

## Terraform

Terraform consumes the operator-only structured document directly:

```bash
nix run .#secrets -- exec-env terraform.json -- terraform plan
```

SOPS supplies the environment without writing or sourcing a plaintext dotenv
file.
