# Secrets design

## Policy

`secrets/secrets.nix` is the source of truth. Each secret declares the systems
that receive it and the users who may operate on it:

```nix
grafana-admin-password = {
  hosts = with hosts; [ paimon ];
  users = with users; [ codgi ];
  expires = "2027-01-01"; # optional
};
```

`hosts.paimon` and `users.codgi` are records built from the SSH public keys in
`pubkeys.nix`. The separate lists express policy, not different cryptography:
both become age recipients, while only `hosts` controls sops-nix deployment.
The record tags make putting a user in `hosts`, or a host in `users`, an
evaluation error.

Both lists default to empty, so operator-only secrets can omit `hosts`, and
host-only secrets can omit `users`.

Age recipient strings are not maintained in Nix. `secrets sync` converts the
declared SSH public keys with `ssh-to-age` and generates `.sops.yaml`. The
conversion is deterministic and handles only public key material.

## Encrypted documents

`data/*.json` are standard structured SOPS documents. The Nix module reads only
their visible keys to locate each declared secret; it does not infer access from
ciphertext metadata. Existing documents may contain several values with the
same policy. Evaluation fails if declarations in one document have different
host or user lists, preventing an accidental union of their access.

New secrets default to `data/<secret>.json`, so their access can change without
moving other values. The operator-only Terraform document remains a bundle so
`sops exec-env` can pass it directly to Terraform without rendering shell code.

`.sops.yaml` and the recipient stanzas embedded in every document are generated
artifacts of the Nix policy. Removing a recipient is not effective until
`secrets rekey` rewrites the encrypted data key.

## Host activation

The generic module selects secrets from `secrets.<name>.hosts` and translates
them to native `sops.secrets` declarations. Consumers keep using:

```nix
config.codgician.secrets.files.<name>.path
config.codgician.secrets.templates.<name>.path
```

SSH host-key decryption is unchanged. On NixOS, sops-nix keeps decrypted
generations on its ramfs under `/run/secrets.d`; `/run/secrets` points to the
active generation. Darwin uses the sops-nix RAM-backed volume. Plaintext does
not enter the Nix store.

## Templates

Composed files remain individually managed under `secrets/templates/`. Each
template references secrets directly in its content:

```nix
{ ref }:
{
  content = ''
    LITELLM_MASTER_KEY=${ref "litellm-master-key"}
  '';
}
```

The module derives dependencies from the `ref` calls in `content`, checks that
the host receives all of them, and substitutes native sops-nix placeholders.
There is no separate reference list.

## Commands

- `secrets sync` generates `.sops.yaml` from the Nix records.
- `secrets check` compares Nix policy, `.sops.yaml`, and embedded recipients
  without decrypting values.
- `secrets create <secret>` creates a declared secret through SOPS.
- `secrets edit <secret>` opens the containing document through SOPS.
- `secrets rekey` syncs policy and runs `sops updatekeys`.
- `secrets exec-env <document.json> -- <command>` runs a command with one SOPS
  document exposed as environment variables.

Operator commands derive an age identity temporarily from the operator SSH
private key. The temporary identity is mode `0600` and removed on exit.
