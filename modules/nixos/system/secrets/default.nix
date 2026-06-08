{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.secrets;
  impermanenceCfg = config.codgician.system.impermanence;

  # Host identity paths used by sops-nix to derive the age decryption key
  # (sops-nix converts the ssh ed25519 host key -> age internally at
  # activation). Mirrors the agenix module's impermanence handling: before the
  # /persist bind-mounts settle, the real key lives under /persist. This path
  # must be readable at the EARLY secrets-for-users phase too, which on an
  # impermanence host requires /persist to be neededForBoot.
  hostIdentityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sshKeyPaths =
    if impermanenceCfg.enable then
      builtins.map (x: impermanenceCfg.path + x) hostIdentityPaths
    else
      hostIdentityPaths;

  # This host's age recipient keys (from pubkeys.nix), used to gate which
  # templates/secrets this host can actually decrypt. Mirrors the agenix module's
  # availability check.
  hostName = config.networking.hostName;
  pubkeyHosts = lib.codgician.registry.pubkeys.hosts;
  thisHostKeys = pubkeyHosts.${hostName} or [ ];
  isRecipient = keys: lib.any (k: builtins.elem k thisHostKeys) keys;

  # Host templates this host can decrypt. Excludes:
  #   - app-scoped templates (terraform.env) -- those render on the operator
  #     workstation via `secrets render`, encrypted to the operator key alone.
  #   - templates whose recipients do not include THIS host -- e.g. anubis-env is
  #     lumine-only, so paimon must not try to render it (it cannot decrypt the
  #     refs and activation would fail).
  #
  # Forcing `t.publicKeys` and `t.refs` triggers lib/sops.nix's eval guards
  # (assertHostScoped via publicKeys, undeclared-ref via refs) for every
  # candidate template, before the recipiency filter narrows to this host.
  libTemplates = lib.filterAttrs (
    _: t: builtins.seq t.refs (!t.app && isRecipient t.publicKeys)
  ) lib.codgician.templates;

  # Raw secrets every host template references, declared as binary sops.secrets
  # so config.sops.placeholder.<ref> exists for the template content. Refs come
  # from lib (sentinel-derived, pure) -- NEVER from config.sops.placeholder, to
  # avoid a self-dependency.
  templateRefs = lib.unique (lib.concatMap (t: t.refs) (builtins.attrValues libTemplates));

  valuesDir = lib.codgician.secretsDir + "/values";

  # A ref declared both as a direct file (cfg.files) and as a template ref would
  # be declared twice in sops.secrets; the genAttrs templateRefs entry wins the
  # `//` merge and silently overrides the file's intended format/owner/group/mode
  # back to binary/defaults. Refuse the ambiguity instead of resolving it
  # silently.
  refFileCollisions = builtins.attrNames (
    lib.filterAttrs (n: _: builtins.elem n templateRefs) cfg.files
  );
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = refFileCollisions == [ ];
            message = ''
              codgician.secrets: ${lib.concatStringsSep ", " refFileCollisions} declared both
              as a direct file and as a template ref. A secret may be one or the
              other, not both (the template wiring would override the file's
              owner/format).
            '';
          }
        ];

        # Expose the rendered-template path seam so env-bundle consumers
        # reference codgician.secrets.templates.<name>.path, not config.sops.*.
        codgician.secrets.templates = lib.mapAttrs (_: _: { }) libTemplates;
      }

      # Real decryption path.
      (lib.mkIf (!cfg.mock) {
        sops = {
          # Explicit (not the openssh.hostKeys default) so the impermanence
          # /persist rewrite is honored at every activation phase.
          age.sshKeyPaths = sshKeyPaths;

          # Direct secrets: passwords (neededForUsers) and raw values consumed
          # as whole files.
          secrets =
            (lib.mapAttrs (_: f: {
              inherit (f)
                sopsFile
                key
                format
                owner
                group
                mode
                neededForUsers
                ;
            }) cfg.files)
            # Plus every raw value referenced by a template.
            // lib.genAttrs templateRefs (ref: {
              sopsFile = valuesDir + "/${ref}";
              format = "binary";
            });

          # Host templates render at activation by substituting the placeholder
          # tokens with decrypted values of the sops.secrets declared above.
          templates = lib.mapAttrs (
            _: t:
            {
              content = t.renderContent (ref: config.sops.placeholder.${ref});
            }
            // lib.optionalAttrs (t ? owner) { inherit (t) owner; }
            // lib.optionalAttrs (t ? group) { inherit (t) group; }
            // lib.optionalAttrs (t ? mode) { inherit (t) mode; }
          ) libTemplates;
        };
      })

      # Mock path (tests only): bypass sops, render templates with plaintext
      # mocks from the registry. A referenced secret with no registered mock
      # throws at eval time -- a mockless reference fails explicitly, never
      # rendering a silent empty value.
      (lib.mkIf cfg.mock {
        warnings = lib.optional (cfg.files != { } || libTemplates != { }) ''
          codgician.secrets.mock is enabled: real sops decryption is bypassed.
          This must only ever happen in tests.
        '';
      })
    ]
  );
}
