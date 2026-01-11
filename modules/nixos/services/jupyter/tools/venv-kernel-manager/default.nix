{
  pkgs,
  ...
}:

pkgs.writeShellApplication {
  name = "jupyter-venv-kernel";

  runtimeInputs = with pkgs; [
    python3
    jupyter
  ];

  text = ''
    # Venv storage location
    VENV_DIR="$HOME/.local/share/jupyter/venvs"

    usage() {
      cat <<EOF
    Usage: jupyter-venv-kernel <command> [args]

    Manage experimental Jupyter venv kernels for rapid prototyping.
    Use these for trying out packages before adding them to stable Nix kernels.

    Commands:
      create <name>                  Create a new empty venv kernel
      create-from <name> <file>      Create kernel from requirements.txt
      delete <name>                  Delete a venv kernel and its environment
      list                           List all available kernels and venvs
      shell <name>                   Spawn a shell inside the venv (for pip install)
      help                           Show this help message

    Examples:
      jupyter-venv-kernel create my-experiment
      jupyter-venv-kernel create-from llm-project requirements.txt
      jupyter-venv-kernel shell my-experiment
      jupyter-venv-kernel delete my-experiment

    Workflow:
      1. Create experimental kernel:  jupyter-venv-kernel create test
      2. Refresh Jupyter and select "Python (test)" kernel
      3. Install packages:            !pip install some-package
      4. Experiment in notebooks
      5. If useful, add to stable Nix kernel config
      6. Delete when done:            jupyter-venv-kernel delete test
    EOF
    }

    create_kernel() {
      local name="$1"
      local venv_path="$VENV_DIR/$name"

      if [ -d "$venv_path" ]; then
        echo "Error: Kernel '$name' already exists at $venv_path" >&2
        exit 1
      fi

      echo "Creating venv for kernel '$name'..."
      mkdir -p "$VENV_DIR"
      python -m venv "$venv_path"

      echo "Installing base packages..."
      "$venv_path/bin/pip" install -q -U pip wheel setuptools
      "$venv_path/bin/pip" install -q ipykernel ipywidgets

      echo "Registering kernel..."
      "$venv_path/bin/python" -m ipykernel install --user \
        --name "$name" \
        --display-name "Python ($name)"

      echo ""
      echo "Kernel '$name' created successfully!"
      echo ""
      echo "Next steps:"
      echo "  1. Refresh your Jupyter browser page"
      echo "  2. Select 'Python ($name)' from kernel picker"
      echo "  3. Install packages: !pip install <package>"
      echo ""
      echo "To delete later: jupyter-venv-kernel delete $name"
    }

    create_from_requirements() {
      local name="$1"
      local requirements_file="$2"

      if [ ! -f "$requirements_file" ]; then
        echo "Error: Requirements file '$requirements_file' not found" >&2
        exit 1
      fi

      local venv_path="$VENV_DIR/$name"

      if [ -d "$venv_path" ]; then
        echo "Error: Kernel '$name' already exists at $venv_path" >&2
        exit 1
      fi

      echo "Creating venv for kernel '$name'..."
      mkdir -p "$VENV_DIR"
      python -m venv "$venv_path"

      echo "Installing base packages..."
      "$venv_path/bin/pip" install -q -U pip wheel setuptools
      "$venv_path/bin/pip" install -q ipykernel ipywidgets

      echo "Installing packages from $requirements_file..."
      "$venv_path/bin/pip" install -r "$requirements_file"

      echo "Registering kernel..."
      "$venv_path/bin/python" -m ipykernel install --user \
        --name "$name" \
        --display-name "Python ($name)"

      echo ""
      echo "Kernel '$name' created with packages from $requirements_file!"
      echo "Refresh your Jupyter browser page to see the new kernel."
    }

    delete_kernel() {
      local name="$1"
      local venv_path="$VENV_DIR/$name"

      if [ ! -d "$venv_path" ]; then
        echo "Warning: Venv for '$name' not found at $venv_path" >&2
      else
        echo "Removing venv..."
        rm -rf "$venv_path"
      fi

      echo "Unregistering kernel..."
      if jupyter kernelspec remove -y "$name" 2>/dev/null; then
        echo "Kernel '$name' deleted successfully!"
      else
        echo "Warning: Kernel spec '$name' not found (may already be deleted)" >&2
      fi
    }

    spawn_shell() {
      local name="$1"
      local venv_path="$VENV_DIR/$name"

      if [ ! -d "$venv_path" ]; then
        echo "Error: Venv '$name' not found at $venv_path" >&2
        echo "Create it first: jupyter-venv-kernel create $name" >&2
        exit 1
      fi

      echo "Entering venv '$name'..."
      echo "Run 'pip install <package>' to add packages."
      echo "Type 'exit' to leave the venv shell."
      echo ""

      # Spawn a subshell with the venv activated
      # shellcheck disable=SC1091
      bash --rcfile <(echo "source '$venv_path/bin/activate'; PS1='(venv:$name) \w \$ '")
    }

    list_kernels() {
      echo "Available Jupyter kernels:"
      echo ""
      jupyter kernelspec list
      echo ""

      if [ -d "$VENV_DIR" ] && [ -n "$(ls -A "$VENV_DIR" 2>/dev/null)" ]; then
        echo "Experimental venvs (managed by jupyter-venv-kernel):"
        for venv in "$VENV_DIR"/*; do
          if [ -d "$venv" ]; then
            local name
            name=$(basename "$venv")
            local size
            size=$(du -sh "$venv" 2>/dev/null | cut -f1)
            local pkg_count
            pkg_count=$("$venv/bin/pip" list --format=freeze 2>/dev/null | wc -l)
            echo "  - $name ($size, $pkg_count packages)"
          fi
        done
      else
        echo "No experimental venvs found."
        echo "Create one with: jupyter-venv-kernel create <name>"
      fi
    }

    # Main command dispatch
    case "''${1:-}" in
      create)
        if [ -z "''${2:-}" ]; then
          echo "Error: Kernel name required" >&2
          echo "Usage: jupyter-venv-kernel create <name>" >&2
          exit 1
        fi
        create_kernel "$2"
        ;;
      create-from)
        if [ -z "''${2:-}" ] || [ -z "''${3:-}" ]; then
          echo "Error: Kernel name and requirements file required" >&2
          echo "Usage: jupyter-venv-kernel create-from <name> <requirements.txt>" >&2
          exit 1
        fi
        create_from_requirements "$2" "$3"
        ;;
      delete)
        if [ -z "''${2:-}" ]; then
          echo "Error: Kernel name required" >&2
          echo "Usage: jupyter-venv-kernel delete <name>" >&2
          exit 1
        fi
        delete_kernel "$2"
        ;;
      shell)
        if [ -z "''${2:-}" ]; then
          echo "Error: Kernel name required" >&2
          echo "Usage: jupyter-venv-kernel shell <name>" >&2
          exit 1
        fi
        spawn_shell "$2"
        ;;
      list)
        list_kernels
        ;;
      help|--help|-h)
        usage
        ;;
      "")
        usage
        ;;
      *)
        echo "Error: Unknown command '$1'" >&2
        echo "" >&2
        usage >&2
        exit 1
        ;;
    esac
  '';

  meta = {
    description = "Manage experimental Jupyter venv kernels";
    longDescription = ''
      Helper tool for creating and managing per-project Python virtual
      environment kernels in Jupyter. Enables rapid experimentation with
      pip packages while maintaining reproducible Nix-managed stable kernels.

      This tool is designed to be used within Jupyter terminals and notebooks,
      not as a standalone system tool.
    '';
    mainProgram = "jupyter-venv-kernel";
  };
}
