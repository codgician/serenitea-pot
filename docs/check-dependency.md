# Checking dependencies

Taking `focalors` host's system configuration as an example. Assume you encounter build failures due to depending on a vulnerable package `nix-2.15.3`, you may try following procedures to understand how this package is introduced.

First check the full list of derivations. `--impure` is needed to apply host shell's environmet variables.

```bash
nix derivation show -r .#nixosConfigurations.focalors.config.system.build.toplevel --impure
```

From its output you will get the derivation we want to check: `/nix/store/3kd50mza2szav6x48wmiib93zl8kj7kf-nix-2.15.3.drv`.

Then let's check why the dependency was introduced:

```bash
nix why-depends --derivation .#nixosConfigurations.focalors.config.system.build.toplevel /nix/store/3kd50mza2szav6x48wmiib93zl8kj7kf-nix-2.15.3.drv --impure
```

We got:

```
/nix/store/raq31vws6bbx4cpc5bw2qg6y1vrkkqj2-nixos-system-focalors-24.05.20240309.3030f18.drv
└───/nix/store/vzk7anfb99zn3h9n13g7x5lwipw5zqlw-etc.drv
    └───/nix/store/pnf6laqy6f66hcfdlkvr7zny7g9mv0jb-user-environment.drv
        └───/nix/store/lv6fmd7pl6f0f29g05llh0s06c0aax8d-home-manager-path.drv
            └───/nix/store/bzaiw98ld8raczx08r882fb4zsk90v7b-rnix-lsp-unstable-2022-11-27.drv
                └───/nix/store/3kd50mza2szav6x48wmiib93zl8kj7kf-nix-2.15.3.drv
```

Now we understand the vulnerable package was introduced by `rnix-lsp-unstable`, a already deprecated package.
