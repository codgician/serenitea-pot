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
  availableDirectSecrets = lib.filterAttrs (
    _: spec: (spec ? publicKeys) && lib.any (k: builtins.elem k thisHostKeys) spec.publicKeys
  ) lib.codgician.registry.secrets;
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

  config = lib.mkIf cfg.enable {
    # Auto-declare a files.<name> for every direct secret this host can decrypt,
    # so consumers only reference `.path` (and override owner/mode when needed)
    # instead of repeating sopsFile boilerplate. sopsFile defaults to
    # values/<name> via the option default; consumers merge owner/group/mode.
    codgician.secrets.files = lib.mapAttrs (_: _: { }) availableDirectSecrets;

    # Darwin has no impermanence, so the host ssh ed25519 key (which sops-nix
    # converts to an age key) lives at the standard path. The NixOS module sets
    # its own sshKeyPaths with the impermanence /persist rewrite.
    sops.age.sshKeyPaths = lib.mkIf isDarwin [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Enforce neededForUsers constraints at the wrapper layer for a clearer
    # error than sops-nix's internal assertion. sops-nix also asserts this, so
    # this is belt-and-suspenders with a friendlier message.
    assertions = lib.mapAttrsToList (n: f: {
      assertion = !f.neededForUsers || (f.owner == "root" && f.group == "root");
      message = ''
        codgician.secrets.files."${n}": neededForUsers requires root:root
        ownership (got ${f.owner}:${f.group}). sops-nix decrypts these before
        users exist, so non-root ownership is impossible.
      '';
    }) cfg.files;
  };
}
