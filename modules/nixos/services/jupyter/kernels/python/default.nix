{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types;

  kind = "python";
  cfg = config.codgician.services.jupyter.kernels.${kind};

  # Only instances that are turned on.
  enabledKernels = lib.filterAttrs (_: icfg: icfg.enable) cfg;

  # Upstream kernel id. Prefixed by kind so that e.g. `python.default` and
  # `ihaskell.default` never collide in the flat `services.jupyter.kernels`.
  mkId = name: "${kind}-${name}";

  # Libraries that manylinux wheels may dlopen at runtime. The FHS sandbox
  # presents them as a normal /usr/lib tree, so the loader resolves them like on
  # any other distro. Add per-instance ones via `extraLibraries`.
  fhsLibraries = with pkgs; [
    stdenv.cc.cc.lib # libstdc++, libgomp, libgcc_s
    glibc
    zlib
    zstd
    openssl
    libffi # CPython stdlib: ssl, ctypes
    blas
    lapack
    libGL
    glib
    freetype
    fontconfig
    expat
    dbus
  ];

  # Build one upstream kernel entry (and its FHS env + launcher) per instance.
  mkKernel =
    name: icfg:
    let
      stateDir = builtins.dirOf icfg.venvPath;

      # Provision the venv on first launch, then exec the kernel. This script is
      # the FHS foreground process (bubblewrap runs --die-with-parent), so we
      # exec ipykernel directly. {connection_file} is passed by Jupyter as $1.
      launcher = pkgs.writeShellScript "jupyter-${mkId name}-launcher" ''
        set -euo pipefail
        venv="${icfg.venvPath}"
        if [ ! -e "$venv/.ready" ]; then
          uv venv --python "${icfg.pythonVersion}" "$venv"
          uv pip install --python "$venv/bin/python" \
            ipykernel ipywidgets ${lib.escapeShellArgs icfg.defaultPackages}
          touch "$venv/.ready"
        fi
        exec "$venv/bin/python" -m ipykernel_launcher -f "$1"
      '';

      # FHS sandbox mimicking a standard Linux distribution for pip/uv parity.
      fhsEnv = pkgs.buildFHSEnv {
        name = "jupyter-fhs-${mkId name}";
        targetPkgs =
          _:
          (with pkgs; [
            uv
            gcc
            gnumake
            pkg-config
            git
          ])
          ++ fhsLibraries
          ++ icfg.extraLibraries;
        profile = ''
          export UV_PYTHON_PREFERENCE=only-managed
          export UV_LINK_MODE=copy
          export UV_CACHE_DIR="${stateDir}/.uv-cache"
          export UV_PYTHON_INSTALL_DIR="${stateDir}/.uv-python"
          # Expose the GPU driver (libcuda.so.1) for pip-installed CUDA wheels.
          export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        '';
        runScript = launcher;
      };
    in
    lib.nameValuePair (mkId name) {
      inherit (icfg) displayName;
      language = "python";
      argv = [
        "${fhsEnv}/bin/jupyter-fhs-${mkId name}"
        "{connection_file}"
      ];
      env = {
        PYTHONUNBUFFERED = "1";
      }
      // icfg.env;
    };
in
{
  options.codgician.services.jupyter.kernels.${kind} = lib.mkOption {
    default = { };
    description = ''
      Python Jupyter kernels, each running uv inside an FHS sandbox so that
      pip/uv binary wheels behave as on any other Linux distribution.

      Each attribute defines an independent instance: declare several to deploy
      multiple Python kernels (e.g. different versions or package sets) on one
      machine. The attribute name is the instance name; the resulting Jupyter
      kernel id is `python-<name>`.
    '';
    example = lib.literalExpression ''
      {
        stable = {
          enable = true;
          pythonVersion = "3.12";
          defaultPackages = [ "numpy" "torch" ];
        };
        edge = {
          enable = true;
          pythonVersion = "3.13";
          defaultPackages = [ ];
        };
      }
    '';
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "this Python kernel instance";

            displayName = lib.mkOption {
              type = types.str;
              default = "Python (${name})";
              defaultText = lib.literalExpression ''"Python (<name>)"'';
              description = "Human-readable name shown in the Jupyter kernel picker.";
            };

            pythonVersion = lib.mkOption {
              type = types.str;
              default = pkgs.python3.pythonVersion;
              defaultText = lib.literalExpression "pkgs.python3.pythonVersion";
              description = ''
                CPython version uv provisions on first launch. uv downloads a
                standalone interpreter (python-build-standalone), so this need
                not match any Python in nixpkgs; the default just tracks
                pkgs.python3.
              '';
            };

            venvPath = lib.mkOption {
              type = types.str;
              default = "/lab/jupyter/venvs/${mkId name}";
              defaultText = lib.literalExpression ''"/lab/jupyter/venvs/python-<name>"'';
              description = ''
                Where this instance's venv (and uv's cache/interpreters) are
                created on first launch. Must be persistent, writable storage:
                nahida is an ephemeral container, so a venv under /var/lib would
                be wiped and force a full reinstall. Each instance must use a
                distinct path.
              '';
            };

            defaultPackages = lib.mkOption {
              type = types.listOf types.str;
              default = [
                "numpy"
                "pandas"
                "matplotlib"
                "scipy"
                "scikit-learn"
              ];
              example = [
                "torch"
                "transformers"
              ];
              description = ''
                Packages uv installs on first launch, alongside
                ipykernel/ipywidgets. Add more later from a notebook with
                `!uv pip install ...`.
              '';
            };

            extraLibraries = lib.mkOption {
              type = types.listOf types.package;
              default = [ ];
              example = lib.literalExpression "[ pkgs.libGLU pkgs.ffmpeg ]";
              description = "Extra native libraries to expose inside the FHS sandbox.";
            };

            env = lib.mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Extra environment variables written to this kernel's kernel.json.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (enabledKernels != { }) {
    services.jupyter.kernels = lib.mapAttrs' mkKernel enabledKernels;

    # Create each instance's state dir owned by the jupyter user. They live on a
    # persistent mount, so no impermanence entry is needed.
    systemd.tmpfiles.rules = lib.mapAttrsToList (
      _: icfg:
      "d ${builtins.dirOf icfg.venvPath} 0755 ${config.codgician.services.jupyter.user} ${config.codgician.services.jupyter.group} -"
    ) enabledKernels;

    # Instance names become part of an on-disk kernel id, so keep them tame.
    assertions = lib.mapAttrsToList (name: _: {
      assertion = builtins.match "[A-Za-z0-9._-]+" name != null;
      message = "jupyter: Python kernel instance name '${name}' must match [A-Za-z0-9._-]+.";
    }) enabledKernels;
  };
}
