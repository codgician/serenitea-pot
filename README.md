# ❄️ Serenitea Pot

<img align="right" height="160" width="160" src="https://github.com/codgician/serenitea-pot/assets/15964984/17d0e39c-9bee-4dd1-9aed-bb8d21f23daf">

[![Built with Nix](https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a)](https://builtwithnix.org)
[![build](https://github.com/codgician/serenitea-pot/actions/workflows/build.yml/badge.svg)](https://github.com/codgician/serenitea-pot/actions/workflows/build.yml)
[![evergreen](https://github.com/codgician/serenitea-pot/actions/workflows/evergreen.yml/badge.svg)](https://github.com/codgician/serenitea-pot/actions/workflows/evergreen.yml)
[![expiry](https://github.com/codgician/serenitea-pot/actions/workflows/expiry.yml/badge.svg)](https://github.com/codgician/serenitea-pot/actions/workflows/expiry.yml)
![Man hours](https://manhours.aiursoft.com/r/github.com/codgician/serenitea-pot.svg)

Home to all my Nix-managed device profiles.

*Naming conventions and logos in this repository are mainly derived from Genshin Impact by miHoYo/HoYoverse.*

## Binary cache

- **Cache URL**: `https://codgician.cachix.org`
- **Public Key**: `codgician.cachix.org-1:v4RtwkbJZJwfDxH5hac1lHehIX6JoSL726vk1ZctN8Y=`

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
nix develop .#repl
```

## Documentation

Checkout `docs` subfolder for more documentation (work in progress).
