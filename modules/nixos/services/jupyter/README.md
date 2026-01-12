# Jupyter Service Module

This module provides a Jupyter notebook/lab service with a two-tier kernel architecture:

- **Stable kernels** (Nix-managed) - Reproducible, version-controlled environments
- **Experimental kernels** (user venvs) - Rapid prototyping with pip packages

## Quick Start

```nix
codgician.services.jupyter = {
  enable = true;
  notebookDir = "/lab/jupyter";
  user = "codgi";

  # Enable experimental venv kernel support
  enableVenvKernels = true;

  # Stable Haskell kernel
  extraKernels.ihaskell = {
    enable = true;
    extraPackages = ps: with ps; [ lens aeson vector ];
  };

  # Stable Python kernel
  extraKernels.python-base.enable = true;

  # Reverse proxy with Authelia
  reverseProxy = {
    enable = true;
    domains = [ "jupyter.example.com" ];
    authelia.enable = true;
  };
};
```

## Two-Tier Kernel Architecture

### Stable Kernels (Nix-managed)

These kernels are defined in your NixOS configuration and managed by Nix:

- **Reproducible**: Same packages every time
- **Version-controlled**: Changes tracked in git
- **Fast startup**: Packages pre-built in Nix store
- **Best for**: Production notebooks, known workflows, teaching

#### Available Stable Kernels

**IHaskell (`extraKernels.ihaskell`)**

Haskell kernel with customizable packages:

```nix
extraKernels.ihaskell = {
  enable = true;
  extraPackages = ps: with ps; [
    # Data manipulation
    lens lens-aeson aeson vector containers text bytestring

    # Visualization
    ihaskell-hvega hvega diagrams diagrams-cairo

    # Web/HTTP
    wreq http-client http-client-tls

    # Math
    statistics scientific
  ];
};
```

**Python Base (`extraKernels.python-base`)**

Python kernel with data science stack:

```nix
extraKernels.python-base = {
  enable = true;
  # Includes by default: numpy, pandas, scipy, matplotlib, seaborn,
  # plotly, scikit-learn, torch, transformers, requests, etc.

  # Add extra packages:
  extraPackages = ps: with ps; [
    openai
    anthropic
    langchain
  ];
};
```

### Experimental Kernels (User Venvs)

For rapid prototyping when you need packages not in your stable kernels.

#### Using `jupyter-venv-kernel`

This tool is available in Jupyter terminals when `enableVenvKernels = true`:

```bash
# Create a new experimental kernel
jupyter-venv-kernel create my-experiment

# Create from requirements.txt
jupyter-venv-kernel create-from project requirements.txt

# List all kernels
jupyter-venv-kernel list

# Enter venv shell to install packages
jupyter-venv-kernel shell my-experiment
# (inside venv) pip install some-package

# Delete when done
jupyter-venv-kernel delete my-experiment
```

#### Workflow

1. **Experiment**: Create venv kernel, install packages with pip
1. **Iterate**: Rapid try/install/discard cycle
1. **Stabilize**: Once satisfied, add packages to Nix kernel config
1. **Clean up**: Delete experimental kernel

#### Example Session

```bash
# In Jupyter terminal:
$ jupyter-venv-kernel create llm-test
Creating venv for kernel 'llm-test'...
Installing base packages...
Registering kernel...
Kernel 'llm-test' created successfully!

# Refresh browser, select "Python (llm-test)" kernel
# In notebook:
!pip install together langchain-together

# ... experiment ...

# Later, in terminal:
$ jupyter-venv-kernel delete llm-test
```

## Configuration Options

### Main Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Jupyter service |
| `ip` | string | `"127.0.0.1"` | Listen address |
| `port` | int | `8888` | Listen port |
| `user` | string | `"jupyter"` | Service user |
| `group` | string | `"jupyter"` | Service group |
| `notebookDir` | string | `"~/"` | Notebook root directory |
| `password` | string | `null` | Password hash (null = use Authelia) |
| `enableVenvKernels` | bool | `true` | Enable venv kernel management |
| `extraTools` | list | `[]` | Extra tools in Jupyter PATH |

### Kernel Options

**IHaskell:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `extraKernels.ihaskell.enable` | bool | `false` | Enable IHaskell kernel |
| `extraKernels.ihaskell.package` | package | `pkgs.ihaskell` | IHaskell package |
| `extraKernels.ihaskell.extraPackages` | function | `_: []` | Extra Haskell packages |

**Python Base:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `extraKernels.python-base.enable` | bool | `false` | Enable Python kernel |
| `extraKernels.python-base.pythonPackage` | package | `pkgs.python3` | Python package |
| `extraKernels.python-base.extraPackages` | function | `_: []` | Extra Python packages |

## Extra Tools

Add command-line tools to the Jupyter environment (available in terminals and `!commands`):

```nix
codgician.services.jupyter = {
  enable = true;
  extraTools = with pkgs; [
    git         # Version control
    graphviz    # Diagram rendering
    pandoc      # Document conversion
    ffmpeg      # Media processing
  ];
};
```

These tools are **only available in Jupyter context**, not in regular SSH sessions.

## Security

### Authentication

The module enforces authentication via assertion. You must either:

1. **Use Authelia** (recommended):

   ```nix
   reverseProxy = {
     enable = true;
     authelia.enable = true;
   };
   ```

1. **Use password**:

   ```nix
   password = "argon2:$argon2id$v=19$m=10240,t=10,p=8$...";
   ```

   Generate with: `python3 -c "from jupyter_server.auth import passwd; print(passwd())"`

### Isolation

- Experimental venvs are isolated per-kernel
- `jupyter-venv-kernel` tool only available in Jupyter context
- Stable kernels run in isolated Nix environments

## Directory Structure

```
modules/nixos/services/jupyter/
├── default.nix              # Main module
├── README.md                # This file
├── kernels/
│   ├── default.nix         # Kernel imports
│   ├── ihaskell/
│   │   └── default.nix     # IHaskell kernel
│   └── python-base/
│       └── default.nix     # Python kernel
└── tools/
    ├── default.nix         # Tool imports
    └── venv-kernel-manager/
        └── default.nix     # jupyter-venv-kernel tool
```

## Impermanence

If using impermanence, ensure these paths persist:

```nix
codgician.system.impermanence.extraItems = [
  "/lab/jupyter"                      # Notebooks
  "/home/codgi/.local/share/jupyter"  # User kernels and venvs
];
```

Or use a notebook directory under `/home` which is typically persisted by default.

## Troubleshooting

### Kernel not showing up

1. Refresh browser page
1. Check kernel is registered: `jupyter kernelspec list`
1. Check service status: `systemctl status jupyter`

### Venv kernel tool not available

Ensure you're running in Jupyter terminal, not SSH:

```bash
# Should work in Jupyter terminal:
jupyter-venv-kernel list

# Won't work in SSH (by design):
ssh user@host
jupyter-venv-kernel  # command not found
```

### Package conflicts in IHaskell

IHaskell is sensitive to GHC version. If packages fail to build:

1. Check nixpkgs for compatible versions
1. Try fewer packages
1. Check IHaskell upstream issues

### GPU not available in Python kernel

Ensure the host has GPU passthrough configured and use `torch` (not `torch-bin`).
Check with: `python -c "import torch; print(torch.cuda.is_available())"`
