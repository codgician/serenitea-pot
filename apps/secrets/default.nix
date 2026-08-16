{
  lib,
  pkgs,
  ...
}:
let
  name = "secrets";
  secretsDir = lib.codgician.secretsDir;
  registry = import (secretsDir + "/secrets.nix");
  dataDir = secretsDir + "/data";
  dataFiles = lib.filterAttrs (fileName: type: type == "regular" && lib.hasSuffix ".json" fileName) (
    builtins.readDir dataDir
  );
  dataDocuments = lib.mapAttrsToList (
    fileName: _:
    let
      data = builtins.fromJSON (builtins.readFile (dataDir + "/${fileName}"));
    in
    {
      path = "data/${fileName}";
      keys = builtins.attrNames (builtins.removeAttrs data [ "sops" ]);
    }
  ) dataFiles;
  declaredKeys = lib.mapAttrsToList (_: secret: secret.key) registry.secrets;
  secretsByKey = builtins.listToAttrs (
    lib.mapAttrsToList (secretName: secret: {
      name = secret.key;
      value = { inherit secretName secret; };
    }) registry.secrets
  );
  dataKeys = lib.concatMap (document: document.keys) dataDocuments;
  documentsFor =
    secret: builtins.filter (document: builtins.elem secret.key document.keys) dataDocuments;
  documentFor =
    secretName: secret:
    let
      matches = documentsFor secret;
      defaultPath = "data/${secretName}.json";
    in
    if matches == [ ] then
      if lib.any (document: document.path == defaultPath) dataDocuments then
        throw "Secret ${secretName} conflicts with existing ${defaultPath}"
      else
        defaultPath
    else if builtins.length matches == 1 then
      (builtins.head matches).path
    else
      throw "SOPS key ${secret.key} occurs in more than one document";
  pendingDocuments = lib.mapAttrsToList (secretName: secret: {
    path = documentFor secretName secret;
    keys = [ secret.key ];
  }) (lib.filterAttrs (_: secret: documentsFor secret == [ ]) registry.secrets);
  documents = dataDocuments ++ pendingDocuments;
  recipientNames = recipients: map (recipient: recipient.name) recipients;
  documentPolicy =
    document:
    let
      entries = map (
        key: secretsByKey.${key} or (throw "SOPS key ${key} is not declared in secrets/secrets.nix")
      ) document.keys;
      first = (builtins.head entries).secret;
      samePolicy =
        secret:
        {
          hosts = recipientNames secret.hosts;
          users = recipientNames secret.users;
        } == {
          hosts = recipientNames first.hosts;
          users = recipientNames first.users;
        };
    in
    assert entries != [ ];
    assert lib.all (entry: samePolicy entry.secret) entries;
    {
      hosts = recipientNames first.hosts;
      users = recipientNames first.users;
    };
  policy =
    assert builtins.length declaredKeys == builtins.length (lib.unique declaredKeys);
    assert lib.all (key: builtins.hasAttr key secretsByKey) dataKeys;
    {
      recipients = {
        hosts = lib.mapAttrs (_: recipient: recipient.sshPublicKeys) registry.hosts;
        users = lib.mapAttrs (_: recipient: recipient.sshPublicKeys) registry.users;
      };
      documents = builtins.listToAttrs (
        map (document: {
          name = document.path;
          value = documentPolicy document;
        }) documents
      );
      secrets = lib.mapAttrs (secretName: secret: {
        key = secret.key;
        document = documentFor secretName secret;
      }) registry.secrets;
    };
  policyFile = pkgs.writeText "sops-policy.json" (builtins.toJSON policy);
in
{
  type = "app";
  meta = {
    description = "Manage structured SOPS documents";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        coreutils
        git
        sops
        ssh-to-age
        yq-go
      ];

      text = ''
        set -euo pipefail

        err() { echo "Error: $*" >&2; exit 1; }
        log() { echo "$*" >&2; }
        repo_root() { git rev-parse --show-toplevel; }

        policy_file=${policyFile}
        identity_file=
        policy_tmp=
        cleanup() {
          [ -z "$identity_file" ] || rm -f -- "$identity_file"
          [ -z "$policy_tmp" ] || rm -f -- "$policy_tmp"
        }
        trap cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        prepare_identity() {
          if [ -n "''${SOPS_AGE_KEY:-}''${SOPS_AGE_KEY_FILE:-}''${SOPS_AGE_KEY_CMD:-}" ]; then
            return
          fi

          local ssh_key runtime_dir passphrase attempt
          ssh_key="''${SOPS_AGE_SSH_PRIVATE_KEY_FILE:-$HOME/.ssh/id_ed25519}"
          [ -f "$ssh_key" ] || err "SOPS operator SSH key not found: $ssh_key"
          runtime_dir="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
          umask 077
          identity_file="$(mktemp "$runtime_dir/sops-age-identity.XXXXXX")"

          if SSH_TO_AGE_PASSPHRASE="" ssh-to-age -private-key -i "$ssh_key" -o "$identity_file" 2>/dev/null; then
            export SOPS_AGE_KEY_FILE="$identity_file"
            return
          fi

          for attempt in 1 2 3; do
            printf 'Enter passphrase for %s (attempt %d/3): ' "$ssh_key" "$attempt" >&2
            IFS= read -r -s passphrase </dev/tty \
              || err "cannot read the SSH key passphrase without a terminal"
            printf '\n' >&2
            if SSH_TO_AGE_PASSPHRASE="$passphrase" ssh-to-age -private-key \
              -i "$ssh_key" -o "$identity_file" 2>/dev/null; then
              unset passphrase
              export SOPS_AGE_KEY_FILE="$identity_file"
              return
            fi
            unset passphrase
          done
          err "failed to unlock $ssh_key"
        }

        generate_policy() {
          local output=$1 path kind principal public_key recipient regex
          local -a recipients
          declare -A seen

          {
            printf 'creation_rules:\n'
            while IFS= read -r path; do
              recipients=()
              seen=()
              for kind in hosts users; do
                while IFS= read -r principal; do
                  while IFS= read -r public_key; do
                    recipient="$(printf '%s\n' "$public_key" | ssh-to-age)"
                    if [ -z "''${seen[$recipient]+set}" ]; then
                      recipients+=("$recipient")
                      seen[$recipient]=1
                    fi
                  done < <(
                    KIND="$kind" PRINCIPAL="$principal" yq -r \
                      '.recipients[strenv(KIND)][strenv(PRINCIPAL)][]' "$policy_file"
                  )
                done < <(
                  PATH_KEY="$path" KIND="$kind" yq -r \
                    '.documents[strenv(PATH_KEY)][strenv(KIND)][]' "$policy_file"
                )
              done
              [ ''${#recipients[@]} -gt 0 ] || err "$path has no recipients"
              regex="''${path//./\\.}"
              printf '  - path_regex: ^%s$\n' "$regex"
              printf '    key_groups:\n      - age:\n'
              printf '          - %s\n' "''${recipients[@]}"
            done < <(yq -r '.documents | keys | .[]' "$policy_file")
          } >"$output"
        }

        sync_policy() {
          local root
          root="$(repo_root)"
          policy_tmp="$(mktemp "$root/secrets/.sops.yaml.XXXXXX")"
          generate_policy "$policy_tmp"
          mv -- "$policy_tmp" "$root/secrets/.sops.yaml"
          policy_tmp=
          git -C "$root" add secrets/.sops.yaml
          log "Generated secrets/.sops.yaml from secrets/secrets.nix"
        }

        check_policy() {
          local root file relpath matches expected actual drift=0
          root="$(repo_root)/secrets"
          cd "$root"
          [ -f .sops.yaml ] || err "secrets/.sops.yaml is missing"

          policy_tmp="$(mktemp "''${TMPDIR:-/tmp}/sops-policy.XXXXXX")"
          generate_policy "$policy_tmp"
          if ! cmp -s .sops.yaml "$policy_tmp"; then
            log "DRIFT: .sops.yaml was not generated from secrets/secrets.nix"
            drift=1
          fi

          shopt -s nullglob
          local files=(data/*.json)
          local rule_count
          rule_count="$(yq -r '.creation_rules | length' .sops.yaml)"
          [ "$rule_count" -eq "''${#files[@]}" ] || {
            log "DRIFT: $rule_count creation rules for ''${#files[@]} documents"
            drift=1
          }

          for file in "''${files[@]}"; do
            relpath="$file"
            # shellcheck disable=SC2016
            matches="$(P="$relpath" yq -r '
              [.creation_rules[] | select(.path_regex as $re | strenv(P) | test($re))] | length
            ' .sops.yaml)"
            if [ "$matches" -ne 1 ]; then
              log "DRIFT: $relpath matches $matches creation rules"
              drift=1
              continue
            fi

            # shellcheck disable=SC2016
            expected="$(P="$relpath" yq -r '
              .creation_rules[]
              | select(.path_regex as $re | strenv(P) | test($re))
              | .key_groups[].age[]
            ' .sops.yaml | sort -u)"
            actual="$(yq -r '.sops.age[].recipient' "$file" | sort -u)"
            if [ "$actual" != "$expected" ]; then
              log "DRIFT: $relpath recipients differ from secrets/secrets.nix"
              drift=1
            else
              log "OK: $relpath"
            fi
          done

          [ "$drift" -eq 0 ] || err "recipient policy drift detected"
        }

        secret_document() {
          local secret=$1
          SECRET="$secret" yq -e -r '.secrets[strenv(SECRET)].document' "$policy_file" 2>/dev/null \
            || err "unknown secret: $secret"
        }

        create_secret() {
          local secret="''${1:-}" root document
          [[ "$secret" =~ ^[a-z0-9-]+$ ]] || err "usage: ${name} create <secret>"
          root="$(repo_root)"
          document="$(secret_document "$secret")"
          [ ! -e "$root/secrets/$document" ] || err "$secret already exists; use edit"
          sync_policy
          prepare_identity
          (cd "$root/secrets" && sops "$document")
          git -C "$root" add "secrets/$document"
        }

        edit_secret() {
          local secret="''${1:-}" root document
          [[ "$secret" =~ ^[a-z0-9-]+$ ]] || err "usage: ${name} edit <secret>"
          root="$(repo_root)"
          document="$(secret_document "$secret")"
          [ -f "$root/secrets/$document" ] || err "$secret has not been created"
          prepare_identity
          (cd "$root/secrets" && sops "$document")
          git -C "$root" add "secrets/$document"
        }

        rekey_documents() {
          local root files
          root="$(repo_root)"
          sync_policy
          prepare_identity
          shopt -s nullglob
          files=("$root"/secrets/data/*.json)
          [ ''${#files[@]} -gt 0 ] || err "no structured SOPS documents"
          (cd "$root/secrets" && sops updatekeys --yes data/*.json)
          git -C "$root" add secrets/data
          check_policy
        }

        exec_environment() {
          local document="''${1:-}" root command
          [ -n "$document" ] || err "usage: ${name} exec-env <document.json> -- <command>"
          shift
          [ "''${1:-}" = -- ] || err "missing -- before command"
          shift
          [ $# -gt 0 ] || err "missing command"
          root="$(repo_root)"
          [ -f "$root/secrets/data/$document" ] || err "unknown document: $document"
          prepare_identity
          printf -v command '%q ' "$@"
          sops exec-env "$root/secrets/data/$document" "$command"
        }

        show_help() {
          cat >&2 <<'EOF'
        secrets - manage structured SOPS documents

        Usage:
          secrets sync
          secrets check
          secrets create <secret>
          secrets edit <secret>
          secrets rekey
          secrets exec-env <document.json> -- <command> [args...]
        EOF
        }

        [ $# -gt 0 ] || { show_help; exit 1; }
        command_name=$1
        shift
        case "$command_name" in
          sync) sync_policy ;;
          check) check_policy ;;
          create) create_secret "$@" ;;
          edit) edit_secret "$@" ;;
          rekey) rekey_documents ;;
          exec-env) exec_environment "$@" ;;
          -h|--help) show_help ;;
          *) err "unknown command: $command_name" ;;
        esac
      '';
    }
  );
}
