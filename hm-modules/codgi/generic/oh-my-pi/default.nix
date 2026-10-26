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

  mkProfileFiles =
    name: agentDir:
    lib.mapAttrs' (
      file: settings:
      lib.nameValuePair "${agentDir}/${file}" {
        source = yamlFormat.generate "omp-${name}-${file}" settings;
        force = true;
      }
    ) profiles.${name}
    // {
      "${agentDir}/AGENTS.md" = {
        text = ''
          # Environment

          This system is managed by Nix on `${pkgs.stdenv.hostPlatform.system}`.
          Prefer an existing project development environment. For a new persistent project environment, use a flake dev shell with direnv only when the user requests it.
        '';
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

  };

  config = lib.mkIf cfg.enable {

    home.packages = [ cfg.package ];
    home.file = {
      ".omp/.env" = {
        source = config.lib.file.mkOutOfStoreSymlink osConfig.codgician.secrets.templates."omp-env".path;
        force = true;
      };
    }
    // mkProfileFiles cfg.defaultProfile ".omp/agent"
    // lib.concatMapAttrs (name: _profile: mkProfileFiles name ".omp/profiles/${name}/agent") profiles;
  };
}
