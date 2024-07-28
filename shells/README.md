# 🐢 Shells

Each subfolder under this path contains a developer shell provided by this flake. To enter a developer shell, execute:

```bash
nix develop .#shellName -c $SHELL
```

To add a new shell, simply create a new folder containing `default.nix`, and name the subfolder after your new shell's name.
