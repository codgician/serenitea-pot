# 🖥️ Hosts

List of machines managed by this nix flake. Following subfolders could be found under current path:

- `darwin`: Hosts running macOS (Darwin)
- `nixos`: Hosts running NixOS (Linux)

## Adding a new host

Just create a new subfolder under the corresponding OS type and name it with the new host name, and supply a `default.nix`. Hosts should comply with [naming convention](../docs/naming-convention.md).