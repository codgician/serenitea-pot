# ❄️ Serenitea Pot

[![build](https://github.com/codgician/serenitea-pot/actions/workflows/build.yml/badge.svg)](https://github.com/codgician/serenitea-pot/actions/workflows/build.yml)
[![evergreen](https://github.com/codgician/serenitea-pot/actions/workflows/evergreen.yml/badge.svg)](https://github.com/codgician/serenitea-pot/actions/workflows/evergreen.yml)
![Man hours](https://manhours.aiursoft.cn/r/github.com/codgician/serenitea-pot.svg)

![logo](https://github.com/codgician/serenitea-pot/assets/15964984/17d0e39c-9bee-4dd1-9aed-bb8d21f23daf)

My fleet of Nix-managed devices.

*Naming conventions and logos in this repository are mainly derived from Genshin Impact by miHoYo/HoYoverse.*

## Quick start

### Develop

Start developing with your own flavor of shell:

```bash
nix develop -c $SHELL
```

Don't have nix flake support? Try this instead:

```bash
nix-shell
```

Format the nix code:

```bash
nix fmt
```

To inspect evaluated values or do experiments, you may run REPL using:

```bash
nix run .#repl
```

## Documentation

Checkout `docs` subfolder for more documentation (work in progress).
