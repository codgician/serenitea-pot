# 💧 Furina

[MacBook Pro (14-inch, 2023)](https://support.apple.com/kb/SP889?viewlocale=en_US&locale=en_US), my daily driver, managed by nix thanks to [nix-darwin](https://github.com/LnL7/nix-darwin).

## Bootstrapping

After installing nix using installer, build the configuration using:

```bash
nix build .#darwinConfigurations.furina.system --extra-experimental-features "nix-command flakes"
```

Afterwards, apply using built `darwin-rebuild`:

```bash
./result/sw/bin/darwin-rebuild switch --flake .
```
