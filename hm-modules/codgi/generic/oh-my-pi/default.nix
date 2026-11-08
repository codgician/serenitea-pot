{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.oh-my-pi;
  inherit (lib) types;

  yamlFormat = pkgs.formats.yaml { };

  profiles = import ./profiles {
    inherit pkgs osConfig;
    extraSkillDirectories = lib.optionals (config.codgician.codgi.herdr.enable or false) [
      "${config.codgician.codgi.herdr.package.src}/skills"
    ];
  };

  # Initial values omp owns afterwards: the setup wizard advances
  # setupVersion itself, so it is seeded once and never reasserted.
  initialSettings = yamlFormat.generate "omp-initial-config.yml" { setupVersion = 3; };

  # omp persists state (setup progress, model picks, /settings) into
  # config.yml, so it must be a mutable file rather than a store symlink.
  # Each activation deep-merges: initial values < omp's writes < Nix settings.
  mkConfigActivation = name: agentDir: ''
    ompConfig=${lib.escapeShellArg "${config.home.homeDirectory}/${agentDir}/config.yml"}
    ompInputs=(${initialSettings})
    if [[ -L "$ompConfig" ]]; then
      run rm -f "$ompConfig"
    elif [[ -s "$ompConfig" ]]; then
      ompInputs+=("$ompConfig")
    fi
    ompInputs+=(${yamlFormat.generate "omp-${name}-config.yml" profiles.${name}."config.yml"})
    ompMerged=$(${lib.getExe pkgs.yq-go} eval-all '. as $item ireduce ({}; . * $item)' "''${ompInputs[@]}")
    run ${pkgs.coreutils}/bin/install -D -m 644 <(printf '%s\n' "$ompMerged") "$ompConfig"
  '';

  mkProfileFiles =
    name: agentDir:
    lib.mapAttrs' (
      file: settings:
      lib.nameValuePair "${agentDir}/${file}" {
        source = yamlFormat.generate "omp-${name}-${file}" settings;
        force = true;
      }
    ) (removeAttrs profiles.${name} [ "config.yml" ])
    // {
      "${agentDir}/AGENTS.md" = {
        text = ''
          # Environment

          ${cfg.context}'';
        force = true;
      };
      "${agentDir}/RULES.md" = {
        text = ''
          # Git commits

          Never add `Co-Authored-By`, `Generated-By`, or other AI or Oh My Pi attribution to commit messages.
          Use the user's configured Git author and committer identity unchanged.

          # Packages

          On this Nix-managed system, use `nix run` or `nix shell` for one-off tools; never install packages imperatively.
        '';
        force = true;
      };
    };

in
{
  options.codgician.codgi.oh-my-pi = {
    enable = lib.mkEnableOption "oh-my-pi (omp)";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.nur.repos.codgician.oh-my-pi-bin;
      defaultText = lib.literalExpression "pkgs.nur.repos.codgician.oh-my-pi-bin";
      description = ''
        The oh-my-pi package to install.
      '';
    };

    defaultProfile = lib.mkOption {
      type = types.enum (builtins.attrNames profiles);
      default = "dendro";
      description = ''
        The oh-my-pi profile selected when no explicit --profile is given.
      '';
    };

    context = lib.mkOption {
      type = types.lines;
      description = ''
        Facts about this machine for the Environment section of the generated
        AGENTS.md. The Nix baseline is always present; other modules append
        machine-specific context.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    codgician.codgi.oh-my-pi.context = lib.mkBefore ''
      This system is managed by Nix on `${pkgs.stdenv.hostPlatform.system}`.
      Prefer an existing project development environment. For a new persistent project environment, use a flake dev shell with direnv only when the user requests it.
    '';

    home.packages = [ cfg.package ];
    home.file = {
      ".omp/.env" = {
        source = config.lib.file.mkOutOfStoreSymlink osConfig.codgician.secrets.templates."omp-env".path;
        force = true;
      };
    }
    // mkProfileFiles cfg.defaultProfile ".omp/agent"
    // lib.concatMapAttrs (name: _profile: mkProfileFiles name ".omp/profiles/${name}/agent") profiles;

    home.activation.ompConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      mkConfigActivation cfg.defaultProfile ".omp/agent"
      + lib.concatMapStrings (name: mkConfigActivation name ".omp/profiles/${name}/agent") (
        builtins.attrNames profiles
      )
    );
  };
}
