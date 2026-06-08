{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.secrets;
  inherit (pkgs.stdenvNoCC) isDarwin;

  valuesDir = lib.codgician.secretsDir + "/values";

  fileType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        sopsFile = lib.mkOption {
          type = lib.types.path;
          default = valuesDir + "/${name}";
          defaultText = "secrets/values/<name>";
          description = ''
            Path to the sops-encrypted file backing secret "${name}".
            Defaults to secrets/values/<name>.
          '';
        };

        key = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = ''
            Key within the sops file to extract for secret "${name}".
            Defaults to the attribute name.
          '';
        };

        format = lib.mkOption {
          type = lib.types.enum [
            "yaml"
            "json"
            "binary"
            "dotenv"
            "ini"
          ];
          default = "binary";
          description = ''
            sops file format for secret "${name}". Defaults to binary
            (whole-file), matching the raw-value secrets in this repo.
          '';
        };

        owner = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = ''
            Owner of secret "${name}". Must be root when neededForUsers is set.
          '';
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = if isDarwin then "admin" else "root";
          description = ''
            Group of secret "${name}". Must be root when neededForUsers is set.
          '';
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
          description = ''
            File mode of secret "${name}". Defaults to 0400 (sops-nix native,
            stricter than agenix's historical 0600). Override per-secret for the
            rare consumer needing broader read access.
          '';
        };

        neededForUsers = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether secret "${name}" must be decrypted before user creation
            (e.g. users.users.*.hashedPasswordFile). Decrypts to
            /run/secrets-for-users/ and MUST be root-owned.
          '';
        };

        path = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            Read-only resolved path where secret "${name}" is decrypted at
            activation. Consumers reference this instead of a hardcoded path.
          '';
        };
      };

      config = {
        # Resolve the decrypted path the same way sops-nix does, so consumers
        # can reference config.codgician.secrets.files.<name>.path without
        # reaching into config.sops.* directly.
        path = if config.neededForUsers then "/run/secrets-for-users/${name}" else "/run/secrets/${name}";
      };
    }
  );

  # Direct registry secrets (those with explicit publicKeys) that THIS host is a
  # recipient of. Template-derived components are excluded: they have no
  # publicKeys here and are wired as sops.secrets refs by the host module, not as
  # consumer-facing files. Mirrors the agenix module's availableSecretNames.
  thisHostKeys = lib.codgician.registry.pubkeys.hosts.${config.networking.hostName} or [ ];
  isRecipient = keys: lib.any (k: builtins.elem k thisHostKeys) keys;
  availableDirectSecrets = lib.filterAttrs (
    _: spec: (spec ? publicKeys) && isRecipient spec.publicKeys
  ) lib.codgician.registry.secrets;

  # Host templates this host can decrypt. Excludes:
  #   - app-scoped templates (terraform.env) -- those render on the operator
  #     workstation via `secrets render`, encrypted to the operator key alone.
  #   - templates whose recipients do not include THIS host -- e.g. anubis-env is
  #     lumine-only, so paimon must not try to render it (it cannot decrypt the
  #     refs and activation would fail).
  #
  # Forcing `t.refs` triggers lib/sops.nix's eval guards (undeclared-ref via
  # refs) for every candidate template, before the recipiency filter narrows to
  # this host.
  libTemplates = lib.filterAttrs (
    _: t: builtins.seq t.refs (!t.app && isRecipient t.publicKeys)
  ) lib.codgician.templates;

  # Raw secrets every host template references, declared as binary sops.secrets
  # so config.sops.placeholder.<ref> exists for the template content. Refs come
  # from lib (sentinel-derived, pure) -- NEVER from config.sops.placeholder, to
  # avoid a self-dependency.
  templateRefs = lib.unique (lib.concatMap (t: t.refs) (builtins.attrValues libTemplates));

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
  options.codgician.secrets = {
    enable = lib.mkEnableOption "codgician sops-nix secrets management" // {
      default = true;
    };

    mock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Test-only: substitute plaintext mock values instead of decrypting real
        sops files. NEVER enable on a real host. A secret referenced without a
        registered mock value must fail explicitly (no silent empty secret).
      '';
    };

    files = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = ''
        Declarative secrets managed via sops-nix. Each entry wraps a
        sops.secrets.<name> declaration and exposes a stable `.path`.
      '';
    };

    templates = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options.path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "/run/secrets/rendered/${name}";
              description = ''
                Read-only rendered path for env-bundle template "${name}".
                Consumers reference this instead of config.sops.templates.*.
              '';
            };
          }
        )
      );
      default = { };
      description = ''
        Rendered env-bundle templates available on this host. Each exposes a
        stable `.path` to the activation-rendered file. Populated by the
        platform secrets module from the host's applicable templates.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Auto-declare a files.<name> for every direct secret this host can
        # decrypt, so consumers only reference `.path` (and override owner/mode
        # when needed) instead of repeating sopsFile boilerplate. sopsFile
        # defaults to values/<name> via the option default; consumers merge
        # owner/group/mode.
        codgician.secrets.files = lib.mapAttrs (_: _: { }) availableDirectSecrets;

        # Expose the rendered-template path seam so env-bundle consumers
        # reference codgician.secrets.templates.<name>.path, not config.sops.*.
        codgician.secrets.templates = lib.mapAttrs (_: _: { }) libTemplates;

        assertions =
          # Enforce neededForUsers constraints at the wrapper layer for a clearer
          # error than sops-nix's internal assertion. sops-nix also asserts this,
          # so this is belt-and-suspenders with a friendlier message.
          (lib.mapAttrsToList (n: f: {
            assertion = !f.neededForUsers || (f.owner == "root" && f.group == "root");
            message = ''
              codgician.secrets.files."${n}": neededForUsers requires root:root
              ownership (got ${f.owner}:${f.group}). sops-nix decrypts these before
              users exist, so non-root ownership is impossible.
            '';
          }) cfg.files)
          ++ [
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
      }

      # Real decryption path. Shared by NixOS and Darwin so a host gets its
      # secrets regardless of platform. On NixOS impermanence hosts the
      # impermanence module overrides sops.age.sshKeyPaths to the /persist path.
      (lib.mkIf (!cfg.mock) {
        sops = {
          # Host ssh ed25519 key (which sops-nix converts to an age key). On
          # Darwin it lives at the standard path and there is no openssh.hostKeys
          # default to fall back on, so set it explicitly. On NixOS, sops-nix's
          # default (ed25519 from services.openssh.hostKeys) covers it, and the
          # impermanence module overrides with the /persist path when enabled.
          age.sshKeyPaths = lib.mkIf isDarwin [ "/etc/ssh/ssh_host_ed25519_key" ];

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
