{ lib, ... }:
let
  # Declarations live in the registry; this file only derives .sops.yaml rules
  # and rendered-template metadata from it.
  registry = import (lib.codgician.secretsDir + "/secrets.nix") {
    pubkeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
  };
  inherit (registry) pubkeys;

  tplDir = lib.codgician.secretsDir + "/templates";
  tplNames = lib.optionals (lib.pathExists tplDir) (lib.codgician.getNixFileNamesWithoutExt tplDir);

  operatorKeys = pubkeys.users.codgi;
  hostKeys = lib.concatLists (builtins.attrValues pubkeys.hosts);

  # Pure: extract the secret names a template's content references via its
  # placeholder tokens. The charset here is the contract every managed secret
  # name must satisfy (see assertName); a name outside it would never be matched
  # and the literal placeholder would leak into a rendered file.
  parseRefs =
    content:
    lib.unique (
      builtins.map builtins.head (
        builtins.filter builtins.isList (builtins.split "<SOPS:([a-z0-9-]+):PLACEHOLDER>" content)
      )
    );

  # A template is `{ ref, pubkeys, ... }: { content; publicKeys; owner?; ... }`.
  # `ref` resolves per caller: the sentinel below (pure ref discovery + the
  # `render` app), `config.sops.placeholder.<n>` (host module at activation), or
  # a plaintext mock (tests). evalTplWith exposes that choice; templateInfo pins
  # the sentinel so ref discovery never depends on runtime config.
  evalTplWith =
    ref: name:
    import "${tplDir}/${name}.nix" {
      inherit ref pubkeys;
    };
  sentinel = name: "<SOPS:${name}:PLACEHOLDER>";

  # Evaluated exactly once per template. Every downstream output (recipients,
  # host wiring, render app) reads from here instead of re-importing/re-parsing
  # per secret, which keeps recipient derivation O(templates + secrets).
  templateInfo = lib.genAttrs tplNames (
    name:
    let
      meta = evalTplWith sentinel name;
      refs = parseRefs meta.content;
      unknown = builtins.filter (r: !(registry.secrets ? ${r})) refs;
    in
    lib.throwIf (unknown != [ ])
      "template '${name}' references undeclared secret(s): ${lib.concatStringsSep ", " unknown}"
      (
        meta
        // {
          inherit refs;
          app = meta.app or false;
        }
      )
  );

  # Inverted index built in one pass: secret name -> recipients contributed by
  # every template that references it. Env-bundle component values inherit their
  # composing template's recipients from here.
  derivedRecipients = builtins.foldl' (
    acc: t: builtins.foldl' (a: r: a // { ${r} = (a.${r} or [ ]) ++ t.publicKeys; }) acc t.refs
  ) { } (builtins.attrValues templateInfo);

  # users.codgi is a single key; membership is one elem, not a list scan.
  operatorKey = builtins.head operatorKeys;

  # Every recipient set must reach the operator (so it can rekey) and contain
  # only ed25519 keys (the only sound ssh->age path).
  assertRecipients =
    name: keys:
    builtins.foldl' (v: c: lib.throwIf c.cond c.msg v) keys [
      {
        cond = !(builtins.elem operatorKey keys);
        msg = "secret '${name}' must include the operator key (use a someHosts/allHosts alias or add users.codgi)";
      }
      {
        cond = builtins.any (k: !(lib.hasPrefix "ssh-ed25519 " k)) keys;
        msg = "sops recipients for '${name}' must be ssh-ed25519 keys";
      }
    ];

  # Every managed secret name must match the placeholder charset.
  assertName =
    n:
    lib.throwIf (builtins.match "[a-z0-9-]+" n == null)
      "sops secret name '${n}' must match [a-z0-9-]+ (uppercase/underscore break placeholder detection)"
      n;

  # A raw value's recipients are the union of its explicit `publicKeys` (direct
  # consumption) and the recipients derived from templates referencing it. A
  # value used both ways widens access, so that requires an explicit opt-in; a
  # value with neither source is unencryptable. Survivors must pass
  # assertRecipients.
  recipientsOf =
    name:
    let
      spec = registry.secrets.${name};
      explicit = spec.publicKeys or [ ];
      derived = derivedRecipients.${name} or [ ];
      recipients = lib.unique (explicit ++ derived);
    in
    lib.throwIf (recipients == [ ])
      "secret '${name}' has no publicKeys and is referenced by no template (unencryptable)"
      (
        lib.throwIf (explicit != [ ] && derived != [ ] && !(spec.allowTemplateRecipientUnion or false))
          "secret '${name}' has both explicit publicKeys and template-derived recipients; set allowTemplateRecipientUnion = true or split it"
          (assertRecipients name recipients)
      );

  # Host (non-app) templates render at activation, so their recipients must
  # include at least one host key or the host cannot decrypt the refs.
  assertHostScoped =
    name: keys:
    lib.throwIf (!(lib.any (k: builtins.elem k hostKeys) keys))
      "host template '${name}' has no host recipient; mark it `app = true` if it is operator-only, or add a host key to its publicKeys"
      keys;
in
rec {
  inherit registry;

  # .sops.yaml creation-rule metadata (consumed by `secrets -- rekey`). Every
  # managed secret is one fully-encrypted raw `values/<name>` file.
  sopsRules = lib.mapAttrsToList (n: _: {
    path = "values/${assertName n}";
    sshKeys = recipientsOf n;
  }) registry.secrets;

  # Text templates with placeholder tokens (consumed by `secrets -- render`).
  renderedTemplates = lib.mapAttrs (_: t: {
    placeholderContent = t.content;
    inherit (t) refs;
  }) templateInfo;

  # Per-template metadata for the host module (consumed by sops.templates wiring).
  # `refs` is derived purely; `renderContent` lets the module substitute
  # config.sops.placeholder (prod) or mocks (tests). owner/group/mode fall back to
  # module defaults when the template omits them. app-scoped templates render on
  # the operator workstation, so the host module skips them.
  templates = lib.mapAttrs (
    name: t:
    {
      inherit (t) refs app;
      publicKeys = if t.app then t.publicKeys else assertHostScoped name t.publicKeys;
      renderContent = ref: (evalTplWith ref name).content;
    }
    // lib.filterAttrs (
      k: _:
      builtins.elem k [
        "owner"
        "group"
        "mode"
      ]
    ) t
  ) templateInfo;
}
