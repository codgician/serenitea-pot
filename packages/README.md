# 📦 Packages

These are pcakcges provided by this flake. The app name is the name of the subfolder.

To build a package for platform `<arch-system>`, execute:

```bash
nix build .#packages.<arch-system>.<package name>
```

To add a new app, simply create a new folder containing `default.nix`, and name the subfolder after your new app's name.
