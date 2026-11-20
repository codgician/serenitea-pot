{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.codgician.services.jupyter;

  # The venv and uv's cache and interpreters live next to the notebooks, on
  # storage that outlives the host's root: a venv under /var/lib would be wiped
  # and force a full reinstall.
  stateDir = "${cfg.notebookDir}/venvs";

  # Provision the venv on first launch with an uv-managed standalone CPython,
  # then exec the kernel. This script is the FHS foreground process (bubblewrap
  # runs --die-with-parent), so we exec ipykernel directly. {connection_file} is
  # passed by Jupyter as $1. Add packages later with `!uv pip install ...`.
  launcher = pkgs.writeShellScript "jupyter-python-default-launcher" ''
    set -euo pipefail
    venv="${stateDir}/python-default"
    if [ ! -e "$venv/.ready" ]; then
      uv venv --python "${pkgs.python3.pythonVersion}" "$venv"
      uv pip install --python "$venv/bin/python" \
        ipykernel ipywidgets ${
          lib.escapeShellArgs [
            "numpy"
            "pandas"
            "matplotlib"
            "scipy"
            "scikit-learn"
            "torch"
            "transformers"
          ]
        }
      touch "$venv/.ready"
    fi
    exec "$venv/bin/python" -m ipykernel_launcher -f "$1"
  '';

  # FHS sandbox mimicking a standard Linux distribution for pip/uv parity.
  fhsEnv = pkgs.buildFHSEnv {
    name = "jupyter-fhs-python-default";
    # The libraries are those manylinux wheels may dlopen at runtime.
    targetPkgs =
      _: with pkgs; [
        uv
        gcc
        gnumake
        pkg-config
        git
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
{
  options.codgician.services.jupyter.kernels.python.enable =
    lib.mkEnableOption "this Python kernel instance";

  config = lib.mkIf (cfg.enable && cfg.kernels.python.enable) {
    services.jupyter.kernels.python-default = {
      displayName = "Python (default)";
      language = "python";
      argv = [
        "${fhsEnv}/bin/jupyter-fhs-python-default"
        "{connection_file}"
      ];
      env.PYTHONUNBUFFERED = "1";
    };

    systemd.tmpfiles.rules = [ "d ${stateDir} 0755 codgi jupyter -" ];
  };
}
