# 🏠 Home manager modules

In this flake, users have their own home-manager modules defined. Thus, modules are not shared among users.

Under each folder named after user name, three subfolders may be found:

- `generic`: compatible with all platforms
- `darwin`: only compatible with macOS (Darwin)
- `nixos`: only compatible with NixOS (Linux)

For OS modules, check out `../modules`.

These home-manager modules are not imported globally. Instead, user-specific modules are only imported when the user enables `createHome`. This is achieved by user module under OS modules folder.
