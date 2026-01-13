{
  config,
  pkgs,
  lib,
  ...
}:
let
  kernelName = "python-lazy";
  cfg = config.codgician.services.jupyter.extraKernels.${kernelName};
  types = lib.types;

  # Libraries needed for pip binary wheels to work on NixOS
  # These provide the shared libraries that manylinux wheels expect
  fhsLibraries =
    with pkgs;
    [
      # Core C/C++ runtime
      stdenv.cc.cc.lib
      glibc
      zlib
      zstd

      # Common dependencies for scientific packages
      blas
      lapack
      libffi
      openssl

      # Graphics/GUI (for matplotlib, etc.)
      libGL
      libGLU
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXcursor
      xorg.libXi
      xorg.libXrandr
      xorg.libXinerama
      xorg.libXxf86vm
      xorg.libxcb
      freetype
      fontconfig

      # Image processing
      libpng
      libjpeg
      libtiff
      libwebp

      # HDF5/data formats
      hdf5

      # Audio (for some ML packages)
      libsndfile

      # Misc
      expat
      glib
      dbus
    ]
    ++ lib.optionals cfg.enableCUDA [
      # CUDA support - only include if explicitly enabled
      linuxPackages.nvidia_x11
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
    ];

  # FHS environment that mimics a standard Linux distribution
  fhsEnv = pkgs.buildFHSEnv {
    name = "jupyter-fhs-python";

    targetPkgs =
      _:
      with pkgs;
      [
        # Python with pip/venv support
        python3
        python3Packages.pip
        python3Packages.virtualenv

        # Essential build tools for compiling packages
        gcc
        gnumake
        pkg-config

        # Git for pip installing from repos
        git

        # All the libraries
      ]
      ++ fhsLibraries;

    # Additional packages available in the environment
    multiPkgs = _: [ ];

    profile = ''
      # Ensure pip uses the venv
      export PIP_REQUIRE_VIRTUALENV=false
    '';

    runScript = "bash";
  };

  # The kernel launcher script that runs inside FHS environment
  kernelLauncher = pkgs.writeShellScript "python-lazy-kernel-launcher" ''
    set -euo pipefail

    VENV_DIR="${cfg.venvPath}"
    CONNECTION_FILE="$1"

    # First-run initialization
    if [ ! -f "$VENV_DIR/.initialized" ]; then
      echo "🚀 First run: Creating Python environment..." >&2
      mkdir -p "$(dirname "$VENV_DIR")"

      # Create venv inside FHS environment
      python3 -m venv "$VENV_DIR"

      echo "📦 Installing base packages..." >&2
      "$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools
      "$VENV_DIR/bin/pip" install ipykernel ipywidgets

      ${lib.optionalString (cfg.requirementsFile != null) ''
        echo "📦 Installing from requirements file..." >&2
        "$VENV_DIR/bin/pip" install -r "${cfg.requirementsFile}"
      ''}

      ${lib.optionalString (cfg.defaultPackages != [ ]) ''
        echo "📦 Installing default packages..." >&2
        "$VENV_DIR/bin/pip" install ${lib.escapeShellArgs cfg.defaultPackages}
      ''}

      touch "$VENV_DIR/.initialized"
      echo "✅ Environment ready!" >&2
    fi

    # Launch the kernel
    exec "$VENV_DIR/bin/python" -m ipykernel_launcher -f "$CONNECTION_FILE"
  '';

  # Wrapper that enters FHS environment and runs the launcher
  kernelWrapper = pkgs.writeShellScriptBin "jupyter-python-lazy-kernel" ''
    exec ${fhsEnv}/bin/jupyter-fhs-python ${kernelLauncher} "$@"
  '';
in
{
  options.codgician.services.jupyter.extraKernels.${kernelName} = {
    enable = lib.mkEnableOption "Lazy Python kernel (pip-based with FHS compatibility)";

    venvPath = lib.mkOption {
      type = types.str;
      default = "/var/lib/jupyter/venvs/${kernelName}";
      description = ''
        Path where the Python virtual environment will be created.
        The venv is created lazily on first kernel launch.
      '';
    };

    requirementsFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./requirements.txt";
      description = ''
        Optional requirements.txt file to install on first kernel initialization.
        Packages are installed via pip inside the FHS environment.
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
        "langchain"
      ];
      description = ''
        Default pip packages to install on first kernel initialization.
        These can be overridden or extended as needed.

        Use an empty list [] for a minimal kernel with only ipykernel.
      '';
    };

    enableCUDA = lib.mkOption {
      type = types.bool;
      default = config.nixpkgs.config.cudaSupport or false;
      defaultText = lib.literalExpression "config.nixpkgs.config.cudaSupport or false";
      description = ''
        Enable CUDA support in the FHS environment.
        This adds NVIDIA drivers and CUDA toolkit to the environment,
        allowing pip-installed PyTorch/TensorFlow to use GPU.

        Defaults to the system-wide cudaSupport setting.
        Note: Requires NVIDIA drivers to be configured on the host system.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.jupyter.kernels.${kernelName} = {
      displayName = "Python (lazy/pip)";
      language = "python";
      argv = [
        "${kernelWrapper}/bin/jupyter-python-lazy-kernel"
        "{connection_file}"
      ];
      env = {
        PYTHONUNBUFFERED = "1";
      };
    };

    # Ensure the venv directory parent exists and is writable by jupyter user
    systemd.tmpfiles.rules =
      let
        jupyterUser = config.codgician.services.jupyter.user;
        jupyterGroup = config.codgician.services.jupyter.group;
        venvParent = builtins.dirOf cfg.venvPath;
      in
      [
        "d ${venvParent} 0755 ${jupyterUser} ${jupyterGroup} -"
      ];
  };
}
