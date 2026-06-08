# Secrets management design

Version: *0.2-202506*

A redesign of secret management for this flake, migrating from
[agenix](https://github.com/ryantm/agenix) to
[sops-nix](https://github.com/Mic92/sops-nix). It removes secret duplication,
keeps a single source of truth, supports fake secrets in VM tests, and preserves
the existing secret-expiry safety net.

## Goals

- **G1 — Store once, reference many.** Each logical secret is encrypted exactly
  once, then referenced from multiple rendered files. No ciphertext duplication.
- **G2 — Composition.** Render per-service environment files, headers, and config
  fragments composed from shared secrets.
- **G3 — Single source of truth.** One key registry (`secrets/pubkeys.nix`)
  drives both `.sops.yaml` and the modules. Recipients are derived in Nix, not
  hand-written YAML.
- **G4 — Secure final state.** Decrypted material lives in `/run` tmpfs, never in
  the Nix store. Each secret is encrypted only to the hosts that need it.
- **G5 — Native interface.** Mirrors `codgician.*` conventions: typed submodule
  options, the `genAttrs` override idiom, and the `generic`/`nixos`/`darwin`
  split.
- **G6 — Fake secrets in tests.** One switch selects fake vs. real; service
  module code is identical in both modes.
- **G7 — Registry-defined mocks.** Mock values are declared beside the secret
  they fake. A secret has one or it does not; referencing a mockless secret in a
  test fails loudly at evaluation.
- **G8 — Preserve expiry tracking.** `expiryDate` survives the migration as a
  first-class schema field; the daily expiry check keeps working and names the
  offending secret.

## Why sops-nix

It is the only option that solves G1/G2 via host-side templates rendered in
`tmpfs`. agenix has no templating, so shared values must be duplicated into
separate encrypted blobs. The usual sops-nix objection — hand-written
`.sops.yaml` — is removed here by generating it from Nix, a pattern used in
production by
[`nix-community/infra`](https://github.com/nix-community/infra/blob/master/sops.nix)
and
[`TUM-DSE/doctor-cluster-config`](https://github.com/TUM-DSE/doctor-cluster-config/blob/master/sops.yaml.nix).

## Core rule

Service modules reference secrets **only** through
`config.codgician.secrets.files.<name>.path`. They never touch `config.sops.*`
or `config.age.*`. This single seam makes the mock/real switch a one-line change
and keeps services backend-agnostic.

A `<name>` resolves to a **template** when it composes values or needs a file
shape (env files, headers), or to a **raw secret** when it is a single value used
verbatim. The module hides which.

Host consumers (NixOS/darwin services) use this seam. A few secrets are consumed by
flake **apps** on the operator's workstation instead, where there is no activation
phase; those follow the *same* registry and `ref` convention but are produced on
demand (see *App-consumed secrets*).

## Three declaration blocks

Every secret lives in exactly one of three blocks. The split is not cosmetic — it
encodes *activation timing* and *recipient derivation*, two things that must be
correct or secrets silently fail.

| Block | Holds | Recipients | Decrypted | Mock |
| --- | --- | --- | --- | --- |
| `secrets` | raw single values composed into templates | **derived** from referencing templates | regular (`/run/secrets`) | registry field |
| `userSecrets` | raw values consumed by user/group creation | **explicit** `publicKeys` | early (`/run/secrets-for-users`) | registry field |
| `templates/*.nix` | files rendered on the machine | **explicit** `publicKeys` | regular (`/run/secrets`) | rendered from refs |

- **`secrets`** is the common case: an API token referenced by one or more
  templates. Its recipients are the union of the `publicKeys` of every template
  that references it — never written by hand (see *Derived recipients*).
- **`userSecrets`** exists for one reason: `users.users.<u>.hashedPasswordFile`
  is read during the `users` activation, which runs *before* sops templates are
  rendered. sops-nix solves this with `neededForUsers = true` (decrypts early,
  to `/run/secrets-for-users`, root-owned only). This block sets that flag
  internally, so `neededForUsers` is never exposed and a password can never be
  declared as a template (the late-render footgun is unrepresentable).
- **`templates/*.nix`** are the machine files. Each is a self-describing Nix file
  (see *Templates as Nix files*).

`neededForUsers` is sops-nix's mechanism, not ours; the only standard consumer
that requires it is `hashedPasswordFile`. Keeping those secrets in a dedicated
block enforces the secrets/templates separation by schema instead of by
convention.

## Layout

```text
secrets/
  pubkeys.nix              # unchanged: SSH keys + aliases (the key registry)
  secrets.nix             # the registry: secrets + userSecrets (values, recipients, mocks, expiry)
  values/<name>.age       # NEW: the ONLY encrypted files (one blob per secret)
  templates/<name>.nix    # NEW: ONLY .nix; render recipes, never encrypted
  .sops.yaml              # GENERATED by `nix run .#secrets-rekey` (committed)
lib/sops.nix              # NEW: renderSopsConfig (creation_rules from registry)
apps/secrets-rekey/       # NEW: regenerate .sops.yaml + updatekeys + git add
apps/secrets-check/       # NEW: assert every .age matches .sops.yaml (CI)
apps/secrets-for/         # NEW: print which secrets a host can decrypt
apps/secrets-edit/        # NEW: rekey + open `sops` on one file + git add
modules/generic/system/secrets/default.nix  # NEW: interface + mock/real switch
modules/nixos/system/secrets/default.nix    # NEW: host identity (ssh key path)
modules/darwin/system/secrets/default.nix   # NEW: host identity (darwin)
```

## Registry

`secrets/pubkeys.nix` is unchanged. `secrets/secrets.nix` declares the two
*value* blocks — `secrets` and `userSecrets`. Templates are not listed here; they
are self-describing files (next section).

```nix
# secrets/secrets.nix
{ pubkeys }: # pubkeys = import ./pubkeys.nix
{
  inherit pubkeys;

  # Raw values composed into templates. Recipients DERIVED from templates;
  # never list publicKeys here. `mock` is the fake used in VM tests.
  secrets = {
    github-token      = { mock = "ghp_mock00000000000000000000000000000000"; };
    anthropic-api-key = { mock = "sk-ant-mock00000000000000000000000000000"; };
    deepseek-api-key  = { mock = "sk-mock0000000000000000000000000000000000"; };
    litellm-oidc      = { mock = "mock-oidc-client-secret"; };

    # Datable values keep an expiry; the check names them (see Expiry). Each
    # secret is one value, so expiry is a single scalar date, not a list.
    nix-access-tokens = {
      mock       = "github.com=ghp_mock0000000000000000000000000000000000";
      expiryDate = "2026-08-12";
    };
    arm-client-secret = {
      mock       = "mock-arm-client-secret";
      expiryDate = "2027-02-04"; # caribert service principal
    };

    # A single value used verbatim is still a `secret`; expose it through a
    # one-line template (see Raw passthrough) so the file layer stays uniform.
    wg-private-key-furina = { mock = "MOCKMOCKMOCKMOCKMOCKMOCKMOCKMOCKMOCKMOCKMz0="; };
  };

  # Secrets consumed by USER/GROUP CREATION (decrypted before the `users`
  # activation). Today: hashed login passwords. The module forces
  # neededForUsers + root ownership; `neededForUsers` is never exposed.
  # Recipients are EXPLICIT — these are not referenced by any template.
  userSecrets = {
    codgi-hashed-password = {
      publicKeys = pubkeys.allHosts;
      mock       = "$6$mockmockmockmock$0XmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmoc0";
    };
    smb-hashed-password = {
      publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon ];
      mock       = "$6$mockmockmockmock$0XmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmockHASHmoc0";
    };
  };
}
```

Recipients for `secrets` are intentionally absent: a value's recipients are
*implied* by the templates that consume it. Writing them here would be a second
source of truth that can drift from the templates (the old design's
`template.publicKeys ⊆ secret.publicKeys` assertion existed only to police that
drift; derivation removes the need for it).

## Templates as Nix files

Each template is a file `secrets/templates/<name>.nix` evaluating to a function
of `{ ref, pubkeys, ... }`. It returns its own `publicKeys`, optional `owner`,
and `content`. The file is the single declaration of the template —
auto-discovered via `lib.codgician.getNixFileNamesWithoutExt`, so adding a file
*is* adding a template.

```nix
# secrets/templates/litellm.env.nix
{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon pubkeys.hosts.lumine ];
  owner = "litellm";
  content = ''
    ANTHROPIC_API_KEY=${ref "anthropic-api-key"}
    DEEPSEEK_API_KEY=${ref "deepseek-api-key"}
    GITHUB_TOKEN=${ref "github-token"}
    GENERIC_CLIENT_SECRET=${ref "litellm-oidc"}
  '';
}
```

```nix
# secrets/templates/mcpo-github-header.nix
{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = "Authorization=Bearer ${ref "github-token"}";
}
```

`ref "name"` is the in-body reference to a raw secret. `github-token` is one
encrypted blob (`secrets/values/github-token.age`) referenced by both templates
— G1/G2. `ref` is supplied by the loader and resolves differently per mode: in
production it returns the sops placeholder for that secret; in tests it returns
the secret's plaintext mock. The *same* `content` therefore renders in both
modes.

### Raw passthrough

A single value used verbatim (a WireGuard key, a token consumed as-is) still
lives in `secrets`, but is exposed through a trivial template so the *file* layer
is uniform — every `files.<name>.path` is backed by either a template or a
`userSecret`, never a bare `secrets` entry. This keeps one code path and one
recipient-derivation rule.

```nix
# secrets/templates/wg-private-key-furina.nix
{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.furina ];
  owner = "systemd-network";
  content = ref "wg-private-key-furina";
}
```

The template name may equal the secret name; they live in different namespaces
(`templates/` vs. `secrets`). Recipient derivation then makes
`wg-private-key-furina` (the value) inherit exactly this template's `publicKeys`.

### Discovering references

References are extracted with a **probe pass**: render `content` with a `ref`
that returns a unique sentinel per name, then scan the output. This is pure (no
mutable state) and drives recipient derivation.

```nix
sentinel = name: "\u0000REF:${name}\u0000";
probeRefs = tmpl:
  let parts = builtins.split "\u0000REF:([a-z0-9-]+)\u0000"
        (tmpl { ref = sentinel; inherit pubkeys; }).content;
  in lib.unique (map builtins.head (lib.filter builtins.isList parts));
```

Rendering for real is the same call with a concrete `ref`:

```nix
render = tmpl: refFn: (tmpl { ref = refFn; inherit pubkeys; }).content;
```

## Derived recipients

A raw secret's recipients are computed, never declared: the union of the
`publicKeys` of every template that references it. Adding a host to a template
(or to an alias in `pubkeys.nix`) therefore propagates to every value that
template composes — one edit site, no `⊆` assertion to satisfy.

```nix
# union of publicKeys over all templates whose probe mentions `secretName`
recipientsOf = secretName:
  lib.unique (lib.concatMap
    (tn: lib.optionals (builtins.elem secretName (refsOf tn)) (pubKeysOf tn))
    tplNames);
```

This is the mechanism behind G1/G2/G3: the encrypted blob for `github-token` is
created for exactly the hosts of the templates that use it, with no hand-kept
list to drift.

## Mock values

Mocks are declared **in the registry**, on the secret itself (`mock = "..."`).
They are plaintext, need no generation, and may be unencrypted (they are fake by
definition and committed to git).

- A secret with `mock = "..."` → that string is used in mock mode.
- A secret **without** `mock` → referencing it in mock mode **throws at
  evaluation**, naming the secret.

```nix
mockValue = name:
  let entry = registry.secrets.${name} or registry.userSecrets.${name} or { };
  in entry.mock or (throw
    "secrets: '${name}' has no mock; a VM test referenced it. Add `mock = \"…\";` in secrets/secrets.nix.");
```

The check is lazy: the `throw` fires only for secrets a configuration actually
reads. A test enabling one service fails only if *that service's* secrets lack
mocks; unrelated mockless secrets stay silent. Declaring the mock beside the
value (rather than in a separate file tree) means a referenced-but-undeclared
secret cannot exist — the registry is the single enumeration.

Write real-shaped mocks where a service validates the format (a valid WireGuard
key, a crypt hash for `hashedPasswordFile`); a smoke test of a plain token can
use any string.

## Expiry

`expiryDate` is an optional scalar `"YYYY-MM-DD"` on a secret entry — a property of
the **value**, which is what actually expires. Because each secret is now a single
value (not an agenix-style multi-variable file), expiry is **one date, not a list**.
This is strictly more precise than the agenix layout, where expiry attached to a
whole bundled file (e.g. `terraform-env`'s expiry really pinned one inner variable;
here that becomes `arm-client-secret.expiryDate`). Templates have no value of their
own and carry no expiry.

`apps/chkexp` reads the registry and scans the value blocks (break-glass or
externally policy-rotated password hashes may also carry a date), folds to the
nearest date, and — the UX upgrade — prints *which* secret is nearest, not just the
bare date. Template refs are deliberately not folded in: doing so would reintroduce
the ambiguous file-level expiry this design removes.

```nix
# apps/chkexp/default.nix (revised core)
datedSecrets = lib.filterAttrs (_: v: v ? expiryDate)
  (registry.secrets // registry.userSecrets);
# min over each secret's expiryDate, so the report reads:
# "Nearest expiry: nix-access-tokens (2026-08-12)".
```

## `.sops.yaml` generation

`.sops.yaml` is read by the `sops` CLI from the git worktree at encrypt time, so
it is materialized into the repo and committed. It is generated from the registry;
never hand-edited.

**Templates are never encrypted, so they get no rules.** sops-nix renders a
template at activation by substituting `sops.placeholder.<ref>` tokens with the
decrypted values of the underlying `sops.secrets` — the template `.nix` carries
only placeholder tokens, no ciphertext (sops-nix `sops.templates` has no
`sopsFile` option). Therefore `.sops.yaml` contains rules **only** for
`values/*.age`. Each raw secret's rule uses its **derived** recipients
(`recipientsOf`), so the encrypted blob is keyed to exactly the hosts whose
templates compose it — `.sops.yaml` and the module agree by construction.

```nix
# lib/sops.nix → lib.codgician.renderSopsConfig
{ lib, ... }:
{
  # sshToAge: ssh-pubkey-string -> age recipient (ssh-to-age, at gen time)
  renderSopsConfig = { registry, recipientsOf, sshToAge }:
    let
      adminAge = map sshToAge registry.pubkeys.users.codgi; # operator decrypts all
      mkRule = path: keys: {
        path_regex = "${lib.escapeRegex path}$";
        key_groups = [ { age = lib.unique ((map sshToAge keys) ++ adminAge); } ];
      };
    in {
      # Only values/*.age exist; templates have no ciphertext and need no rule.
      creation_rules =
        # raw secrets: recipients DERIVED from referencing templates
        lib.mapAttrsToList (n: _: mkRule "values/${n}.age" (recipientsOf n)) registry.secrets
        # userSecrets: recipients EXPLICIT
        ++ lib.mapAttrsToList (n: s: mkRule "values/${n}.age" s.publicKeys) registry.userSecrets;
    };
}
```

The operator key (`codgi`) is added to **every** rule. This is what lets a host
be added and all files re-keyed from the operator's laptop, without any target
host's private key (see *Adding a host*).

## App-consumed secrets

Most secrets are consumed by NixOS/darwin **hosts**: sops-nix renders templates and
materializes secrets into `/run` at *activation*. Some secrets are instead consumed
by **flake apps** run on the operator's workstation (`nix run .#tfmgr`), where there
is no activation phase. These follow the **same registry and the same `ref` template
convention** — the only difference is *when and how* a file is produced.

### One rule: `ref` substitution is always raw

A template's `${ref "name"}` means exactly "insert the raw decrypted value here",
in every consumer, identically. There is **no** format-aware escaping: substitution
is pure string replacement, the same operation sops-nix performs at host activation.
This is what keeps host-render and app-render the *same* mechanism rather than two
that merely look alike.

The corollary (and the dividing line for *how* an app secret is consumed):

> If raw substitution would produce invalid syntax, the file must be consumed
> **whole**, not templated.

So a structured document (a JSON credential whose `private_key` carries `\n` that
must survive byte-for-byte) is never composed through string substitution. It is
stored as its own fully-encrypted raw value and handed to the consumer as a *file
path*, leaving its bytes untouched.

### One shape: every secret is a fully-encrypted raw value

Every managed secret is a single opaque `secrets/values/<name>` sops blob —
nothing is partially encrypted, so no metadata (a credential's `client_email`,
`project_id`, …) ever lands in git in cleartext. What differs is only *how an app
turns that blob into something its consumer can read*:

| Consumption | Built by app via | Example |
| --- | --- | --- |
| **Composed text** (env files, configs) | `nix run .#secrets -- render <name>` decrypts each `ref`ed value and raw-substitutes it into the template → text on tmpfs | `terraform.env` (4 `ARM_*`/`CLOUDFLARE_*` vars) |
| **Whole file** (structured credential) | `sops decrypt` the raw value → a `0600` tmpfs file; pass its path to the consumer | `gcp-credentials` (GCP service-account JSON) |

Both live in `secrets/values/`, both are recipients-derived/explicit through the
same `.sops.yaml` generation, both are mockable. A composed template reads several
values and substitutes; a structured credential is decrypted once and consumed as a
path — but it is the *same* raw blob shape underneath, never a special on-disk form.

### `render`: the app-side of activation

`nix run .#secrets -- render <template>` is the workstation equivalent of host
activation for a **text** template: it decrypts the raw `secrets` the template
`ref`s, performs the *same raw* placeholder substitution, and writes the result to a
`0600` tmpfs file (`$XDG_RUNTIME_DIR`/`/dev/shm`). The app sets the file as its env
source / path and removes it on exit (`trap`). No `jq`, no composition — pure
substitution, identical to host render.

### Structured credentials: decrypted whole, never templated

A GCP service-account credential is a structured document whose `private_key`
contains embedded `\n`, so it must round-trip byte-for-byte and can never be
composed through string substitution. It is stored as a single **fully-encrypted**
raw value (`secrets/values/gcp-credentials`): the whole JSON is opaque ciphertext,
so the service-account identity (`client_email`/`project_id`) is not exposed in git.
The app decrypts it once to a `0600` tmpfs file and passes that path to the consumer
(`GOOGLE_APPLICATION_CREDENTIALS`), removing it on exit. The name omits a `.json`
extension to satisfy the `[a-z0-9-]+` secret-name contract — the consumer reads the
file's *contents*, so the filename is irrelevant.

### Terraform, concretely

```text
secrets/templates/terraform.env.nix   # text template: ARM_*/CLOUDFLARE_* via ${ref}
secrets/values/arm-client-secret      # raw secrets, one sops file each
secrets/values/arm-access-key
secrets/values/cloudflare-api-token
secrets/values/cloudflare-email
secrets/values/gcp-credentials        # raw value: fully-encrypted GCP JSON
```

`tfmgr` renders `terraform.env` (env vars) and decrypts `gcp-credentials` to a
tmpfs file (`GOOGLE_APPLICATION_CREDENTIALS`), then runs terraform. All recipients
are the operator key; no host is involved.

## Operator apps

Four thin `writeShellApplication` wrappers. They exist because the dangerous
sops-nix steps (regenerate-then-`updatekeys`, ordering) must be atomic and
unskippable rather than remembered.

```nix
# nix run .#secrets-rekey   — reconcile .sops.yaml AND ciphertext
#   nix eval .#sopsConfig | yj -jy > .sops.yaml
#   git add .sops.yaml
#   sops updatekeys --yes secrets/values/*.age   # only encrypted files
#   git add secrets/values
# Use after: adding a host, changing recipients, adding/retargeting a template.

# nix run .#secrets-edit -- <name>   — add or rotate one secret
#   secrets-rekey                       # ensure rules current first
#   sops secrets/values/<name>.age      # raw values are the only ciphertext
#   git add the touched .age
# Prints a reminder if <name> carries expiryDate.

# nix run .#secrets-for -- <host>    — audit
#   prints the raw secrets + templates <host> is a recipient of
#   (reuses the module's availableFor / pubKeysOf logic)

# nix run .#secrets-check            — CI drift guard (see below)

# nix run .#secrets-render -- <template>   — app-side activation
#   decrypt the raw secrets a TEXT template ref's, raw-substitute the
#   placeholders, write 0600 tmpfs file; print its path. For app consumers
#   that have no host activation (e.g. tfmgr). Structured secrets use
#   `sops exec-file` directly, not this.
```

### `secrets-check`: closing the policy/ciphertext gap

The defining hazard of sops-nix versus agenix-rekey: editing `.sops.yaml`
declares *who should* decrypt a file but does **not** re-encrypt it. Until
`sops updatekeys` runs, every `.age` keeps its **old** recipient set. The flake
still evaluates; `nix flake check` still passes; the new host simply cannot
decrypt — discovered only when it boots. `secrets-check` converts that
invisible, deploy-time failure into a visible CI failure by asserting that each
file's *actual* age recipients match what `.sops.yaml` *says* they should be.

There is no `sops updatekeys --check`/dry-run mode in current sops, and
`sops filestatus` only reports encrypted/not — neither answers "is this file
keyed to the right set?". The robust, decryption-free method is to read the
recipients straight from the **unencrypted SOPS metadata** and compare sets:

```bash
# actual recipients of one file (no decryption, no private key needed):
sops_recipients() { yq -r '.sops.age[].recipient' "$1" | sort -u; }

# expected recipients come from the SAME registry that writes .sops.yaml,
# converted with ssh-to-age and sorted/deduped. Mismatch on any file → exit 1.
```

Set equality is sound here because the design uses a **single flat age recipient
list per file** — no `key_groups`, no Shamir threshold. Ordering, comments, and
duplicates are normalized away by `sort -u`. (If `key_groups`/Shamir were ever
introduced, this check would need to compare group structure and threshold too;
the design deliberately avoids them so set-equality stays valid.) Keep every
managed file in one parseable SOPS format and fail fast on any unsupported
metadata shape.

It mirrors the existing `chkexp`/`evergreen`/`expiry` cron philosophy: a cheap,
read-only invariant that fails loudly before a box is touched.

## Module

`codgician.secrets` replaces `codgician.system.agenix`, following the
`generic`/`nixos` split.

### Interface

An attribute set of typed submodules, mirroring `config.sops.secrets.<name>`.
Attributes (not a `ref` function) are used because they are idiomatic, fail fast
on a wrong name, are introspectable, and carry typed `owner`/`group`/`mode`.
Attribute values are lazy, so mocks are read only for secrets a configuration
uses.

### Generic module

```nix
# modules/generic/system/secrets/default.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.secrets;
  secretsDir = lib.codgician.secretsDir;
  pubkeys = import "${secretsDir}/pubkeys.nix";
  registry = import "${secretsDir}/secrets.nix" { inherit pubkeys; };

  # Discover templates: secrets/templates/<name>.nix → loaded once.
  tplDir = "${secretsDir}/templates";
  tplNames = lib.codgician.getNixFileNamesWithoutExt tplDir;
  templates = lib.genAttrs tplNames (n: import "${tplDir}/${n}.nix");

  isTemplate = name: templates ? ${name};
  isUserSecret = name: registry.userSecrets ? ${name};

  # Probe (sentinel ref) and real render, both pure.
  sentinel = name: "\u0000REF:${name}\u0000";
  evalTpl = name: refFn: (templates.${name}) { ref = refFn; inherit (registry) pubkeys; };
  refsOf = name:
    let parts = builtins.split "\u0000REF:([a-z0-9-]+)\u0000" (evalTpl name sentinel).content;
    in lib.unique (map builtins.head (lib.filter builtins.isList parts));
  pubKeysOf = name:
    if isTemplate name then (evalTpl name (_: "")).publicKeys
    else if isUserSecret name then registry.userSecrets.${name}.publicKeys
    else recipientsOf name;

  # A raw secret's recipients = union of publicKeys of templates that ref it.
  recipientsOf = secretName:
    lib.unique (lib.concatMap
      (tn: lib.optionals (builtins.elem secretName (refsOf tn)) (pubKeysOf tn))
      tplNames);

  # Which secrets/templates is THIS host a recipient of?
  myKey = pubkeys.hosts.${config.networking.hostName} or [ ];
  availableFor = publicKeys: myKey != [ ] && builtins.elem (builtins.head myKey) publicKeys;

  # The public "files": every template + every userSecret (raw values are
  # surfaced through their passthrough template, so they are not listed here).
  fileNames = tplNames ++ builtins.attrNames registry.userSecrets;
  availableNames = lib.filter (n: availableFor (pubKeysOf n)) fileNames;

  mockValue = name:
    let entry = registry.secrets.${name} or registry.userSecrets.${name} or { };
    in entry.mock or (throw
      "secrets: '${name}' has no mock; a VM test referenced it. Add `mock = \"…\";` in secrets/secrets.nix.");

  mkFiles = pathFn: lib.genAttrs availableNames (n: { path = pathFn n; });
in
{
  options.codgician.secrets = {
    mock = lib.mkEnableOption "fake plaintext secrets (for VM tests)";

    # Computed, read-only: the file each consumer references via `.path`.
    files = lib.mkOption {
      readOnly = true;
      type = lib.types.attrsOf (lib.types.submodule {
        options.path = lib.mkOption { type = lib.types.path; };
      });
    };
  };

  config = lib.mkMerge [
    # ── PRODUCTION: sops-nix, real encryption, tmpfs ──
    (lib.mkIf (!cfg.mock) {
      # userSecrets: early-decrypt, root-owned. neededForUsers hidden here.
      sops.secrets = lib.genAttrs
        (lib.filter isUserSecret availableNames)
        (n: {
          sopsFile = "${secretsDir}/values/${n}.age";
          neededForUsers = true;
        });

      sops.templates = lib.genAttrs
        (lib.filter isTemplate availableNames)
        (n: {
          owner = (evalTpl n (_: "")).owner or "root";
          content = (evalTpl n (r: config.sops.placeholder.${r})).content;
        });

      codgician.secrets.files = mkFiles
        (n: if isTemplate n
            then config.sops.templates.${n}.path
            else config.sops.secrets.${n}.path); # userSecret

      # Raw `secrets` referenced by templates are emitted as sops.secrets too,
      # so sops.placeholder.<r> resolves. (Only those a template here uses.)
      sops.secrets = lib.genAttrs
        (lib.unique (lib.concatMap refsOf (lib.filter isTemplate availableNames)))
        (n: { sopsFile = "${secretsDir}/values/${n}.age"; });
    })

    # ── TEST: plaintext mocks. No keys, no .age, no .sops.yaml. ──
    (lib.mkIf cfg.mock {
      codgician.secrets.files = mkFiles (n:
        toString (pkgs.writeText "mock-${n}" (
          if isTemplate n then (evalTpl n mockValue).content else mockValue n
        )));
    })
  ];
}
```

> Note: the two `sops.secrets = …` blocks above are merged by the module system;
> shown separately for clarity (userSecrets vs. template-referenced raw secrets).

### NixOS module (host identity)

```nix
# modules/nixos/system/secrets/default.nix
{ config, lib, ... }:
lib.mkIf (!config.codgician.secrets.mock) {
  sops.age.sshKeyPaths =
    let p = config.codgician.system.impermanence;
    in [ ((lib.optionalString p.enable p.path) + "/etc/ssh/ssh_host_ed25519_key") ];
}
```

Darwin's identity path is set analogously in
`modules/darwin/system/secrets/default.nix`.

## Consumer migration

```nix
# env file: composes anthropic-api-key + github-token + ... (template)
environmentFile = config.codgician.secrets.files."litellm.env".path;

# header: shapes the shared github-token (template)
headers.Authorization._secret = config.codgician.secrets.files."mcpo-github-header".path;

# single value used verbatim (passthrough template)
wireguardPeers.privateKeyFile = config.codgician.secrets.files."wg-private-key-furina".path;
```

Ownership is set on the template (`owner = "systemd-network";` in the passthrough
file) or, for `userSecrets`, fixed to root by the module. There is no per-secret
ownership block in the registry: ownership belongs to the *file*, which is the
template or the userSecret.

The current `codgician.users` wiring maps cleanly onto the new blocks:

| Old (`modules/generic/users`) | New |
| --- | --- |
| `hashedPasswordAgeFile` → `users.users.<u>.hashedPasswordFile` | `userSecrets.<u>-hashed-password` (module sets `neededForUsers`) |
| `passwordAgeFile` (plaintext, not login) | `secrets` + passthrough template |
| `extraAgeFiles` (user-owned) | `secrets` + passthrough template, `owner = <u>` |

Constraint, now enforced by schema rather than prose: a secret consumed by
`hashedPasswordFile` **must** be a `userSecret`. Templates render after user
creation and cannot be used there; because passwords live in their own block,
declaring one as a template is impossible.

## Testing

Mock mode is driven by the single `codgician.secrets.mock` flag. In mock mode the
module emits **no** `sops`/`age` options, so the production failure modes do not
apply: no host-to-recipient filtering, no `.age` path assertions, no host-key
decryption at boot. Files come from `pkgs.writeText` fed by each secret's
registry `mock`; template mocks preserve the real file shape.

```nix
# tests/litellm/default.nix
{ lib, pkgs, inputs, outputs, ... }:
let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
  system = pkgs.stdenv.hostPlatform.system;
  commonDefaults = {
    imports = lib.codgician.mkNixosModules system { };
    nixpkgs.overlays = pkgs.overlays;
    codgician.secrets.mock = true; # ← fake secrets; the whole mechanism
    _module.args = { inherit inputs outputs system; };
  };
in
{
  litellm = nixos-lib.runTest {
    name = "litellm-smoke";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = { codgician.services.litellm.enable = true; };
    testScript = ''
      machine.start()
      machine.wait_for_unit("litellm.service")
    '';
  };
}
```

This requires `secrets.anthropic-api-key.mock`, `secrets.github-token.mock`, etc.
(every secret `litellm.env` references). A missing one fails the build naming the
secret.

## Operational workflows

### Add a secret

```bash
# 1. secrets.nix: add to `secrets` (mock = "…"; expiryDate if datable)
# 2. write/extend a template under secrets/templates/ that ref's it
#    (or a passthrough template if used verbatim)
# 3. encrypt + reconcile in one step:
nix run .#secrets-edit -- <name>
# 4. consumer: ...files."<template-name>".path
```

`secrets-edit` runs `secrets-rekey` first, so `.sops.yaml` has the rule before
`sops` encrypts (closes the gen-before-encrypt ordering trap and the
`validateSopsFiles` bootstrap window).

### Refresh (rotate) a secret

```bash
nix run .#secrets-edit -- github-token   # one blob; all templates pick it up
```

One command, zero recipient math, all consumers update on next rebuild. If the
secret carries `expiryDate`, `secrets-edit` reminds you to bump the date. To
rotate because a host was *removed*, that is a recipient change — see below.

### Register a secret with an expiry date

```nix
# secrets.nix
secrets.nix-access-tokens = {
  mock        = "github.com=ghp_mock…";
  expiryDate = "2026-08-12";
};
```

`nix run .#chkexp` (and the daily `expiry.yml`) then reports it by name when
within 30 days. Expiry lives on the value, so decomposing a former multi-var
file pins the *exact* variable that expires.

### Add a host

```bash
# 1. pubkeys.nix: add the host's ed25519 pubkey (and to the aliases it joins)
# 2. grant the subset it needs: add it to the relevant templates'/userSecrets'
#    publicKeys (raw `secrets` follow automatically via derivation)
# 3. reconcile policy AND ciphertext in one step:
nix run .#secrets-rekey      # = gen .sops.yaml + updatekeys over BOTH globs
git add secrets
# 4. verify before deploy:
nix run .#secrets-for -- <host>   # did it get what you intended?
nix run .#secrets-check           # are all .age actually re-keyed?
nixos-rebuild switch --flake .#<host>
```

The decisive point: **`secrets-rekey` is mandatory and `secrets-check` proves it
ran.** Adding the pubkey and regenerating `.sops.yaml` alone leaves every `.age`
encrypted to the *old* set; the flake evaluates clean but the new host cannot
decrypt until `updatekeys` re-encrypts. `secrets-rekey` does both halves over
`values/*.age` (the only ciphertext); `secrets-check` fails CI if any file
drifted.

Because the operator key is on every rule, `secrets-rekey` runs entirely from the
operator's laptop — no target host private key needed. The operator key is
passphrase-protected, so a bulk rekey decrypts each file once; `ssh-add` first to
avoid per-file prompts.

#### New-host cold start

A brand-new host cannot decrypt anything until its `ssh_host_ed25519_key` exists,
yet you encrypt *to* that key before first boot. Resolve the circularity by
pre-seeding identity:

1. Generate the host key pair ahead of install; put the **public** key in
   `pubkeys.nix`. On impermanence hosts the **private** key must live on the
   persistent volume (the path in `config.codgician.system.impermanence`), or it
   is wiped on boot and decryption fails.
1. `secrets-rekey` so the host is a recipient in ciphertext.
1. First `nixos-rebuild` then decrypts normally.

(Equivalently: deploy once laying down only SSH host keys, `secrets-rekey`, then
deploy again with secrets.)

## Migration from agenix

The sections above describe the **end state** (agenix gone), where the registry
is `secrets/secrets.nix`. During migration that name is still occupied by the
agenix registry, so the new file is introduced transitionally as
`secrets/registry.nix` and renamed in the final step.

**The migration unit is the secret, not the host.** Most agenix files are shared
across many hosts (`litellm-env` → 4 hosts; `claude-code-env`, `nix-access-tokens`,
`codgi-hashed-password` → `allHosts`), so "migrate one host" is not well defined:
flipping a single host's consumer would force that one secret to exist in *both*
formats and put *both* modules on the same machine. We avoid that entirely by
separating the **data** migration from the **code** cutover:

- **Phase 1 re-encrypts data alongside the originals** — only the `sops`/`agenix`
  CLIs run together (trivial); no host config changes, nothing deploys.
- **Phase 2 swaps the module fleet-wide in one commit** — so **no host ever
  evaluates both modules**. Deploys are then rolled out per host at your pace
  (the new blobs are already keyed to every recipient), recovering incremental
  rollout safety without any module coexistence.

### Phase 1 — data (no host config touched)

```text
For each entry in the agenix registry (old secrets/secrets.nix):
  classify → { raw value (→ secrets) | composed file (→ split into values + template)
             | hashed login password (→ userSecrets) }
  declare it in the NEW secrets/registry.nix; carry expiryDate onto the VALUE
  (preserve inline var comments)
```

1. **Classify every `.age`** up front into a table (value / template / userSecret
   - target recipients + expiry). The `*-env.age` blobs (`litellm-env`,
     `open-webui-env`, `vllm-env`, …) each decompose into several raw values + one
     template — the bulk of the human effort, semantic not mechanical.
1. **Re-encrypt with fidelity, store-safe.** `nix run .#migrate-secret -- <name>`
   pipes `sops -e <(agenix -d <old>)` so plaintext flows only through process
   substitution — **never** a store path, `/tmp`, or stdout — and **diffs by exit
   code only** to prove the value round-tripped (no bytes printed). New blobs land
   at `secrets/values/*.age` beside the untouched agenix files. Your SSH key is
   passphrase-protected; `ssh-add` once before the batch.
1. **Authoring is secret-free.** The registry, templates, module, `lib/sops.nix`,
   and apps are written from **public keys and structure** only; `.sops.yaml` is
   generated from public keys (`ssh-to-age`). None of this touches plaintext, so it
   can be staged and reviewed before any secret is decrypted.

At the end of Phase 1 the new system is fully built and encrypted but **not wired
in**: the old agenix module still drives every host, `nix flake check` is green,
and nothing has deployed.

### Phase 2 — atomic code cutover, then staggered deploy

1. **One cutover commit, fleet-wide.** Flip every consumer
   `config.age.secrets.<n>.path` → `config.codgician.secrets.files.<n>.path`,
   swap `codgician.system.agenix` → `codgician.secrets`, and migrate the four
   password secrets (`codgi-hashed-password`, `smb-hashed-password`,
   `smb-qiaoying-hashed-password`, `kiosk-hashed-password`) into `userSecrets`
   (the module restores `neededForUsers`; update `modules/generic/users` to source
   `hashedPasswordFile` from `…files.<n>.path`). No host evaluates both modules at
   any point.
1. **Gate the commit before deploying anything.** `nix run .#secrets-check` proves
   every `values/*.age` is keyed to the right recipients; VM tests with
   `codgician.secrets.mock = true` prove every service evaluates and boots on the
   new wiring. Both run **without real secrets and without per-host coexistence**,
   replacing the per-host "verify in production" step.
1. **Roll deploys per host.** `nixos-rebuild switch --flake .#<host>` one machine
   at a time, at your pace — every host now runs only sops, the staggering is
   purely *when* each box switches generation.
1. **Decommission agenix** once all hosts are on the new generation: delete the
   agenix module wiring, `lib/secrets.nix`, and the old agenix registry; then
   `git mv secrets/registry.nix secrets/secrets.nix` and repoint the one import in
   the secrets module. The tree now matches the *Layout* above.

## Tradeoffs

- **Policy vs. ciphertext split.** `.sops.yaml` is checked by eval; `.age`
  recipients are not. `secrets-check` is what makes this safe — treat it as
  required CI, not optional.
- **Two-phase recipient updates.** A recipient change needs `secrets-rekey`
  (regenerate + `updatekeys`) versus agenix-rekey's rekey-on-eval. Wrapped into
  one app; the cost is one operator decrypt per file.
- **Bootstrap ordering.** With `validateSopsFiles = true`, a new value file must
  exist before evaluation; `secrets-edit` orders this for you. Mock mode is
  unaffected.
- **Atomic code cutover.** Because secrets are shared across hosts, the module
  swap is one fleet-wide commit, not a per-host migration. Pre-deploy gates
  (`secrets-check` + mock VM tests) substitute for incremental in-production
  verification; deploys still roll per host.
- **No generators.** sops-nix has no secret generator; WireGuard keys etc. are
  created manually.
- **Consumer migration.** All consumers move from `config.age.secrets.<name>.path`
  to `config.codgician.secrets.files.<name>.path` — mechanical but repo-wide.
