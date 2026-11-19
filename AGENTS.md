# AGENTS.md

Nix flake monorepo managing NixOS and macOS (nix-darwin) hosts.
Modules hold mechanisms, one opinionated configuration each; a host's files hold everything else about that host, written out in full.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform  # Terraform management
```

## Layout

- **Hosts**: a folder `hosts/{darwin,nixos}/<name>/` defines a host. Its `default.nix` is the manifest `{ system; cudaSupport ? false; modules = [ … ]; }` (`cudaSupport` on NixOS only); `hosts/default.nix` builds every folder with `lib.codgician.mk{Nixos,Darwin}System`. Nothing is shared between hosts except modules (see [Module or host](#module-or-host)). The order of `modules` decides how list options merge, so keep it when editing
- **Inventory**: `inventory.nix`, plain data that more than one host, module or flake output reads (see [Inventory](#inventory)). `lib/inventory.nix` holds its schema, its checks and what is derived from it
- **Modules**: `modules/{generic,nixos,darwin}/`, namespace `codgician.*` (services: `codgician.services.<name>`)
- **Home Manager modules**: `hm-modules/codgi/{generic,nixos,darwin}/<name>/`, namespace `codgician.codgi.<name>`
- **Secrets**: registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/`, Terranix syntax; the CNAMEs of public names come from `lib.codgician.published.dnsNames`

What a host runs: the `enable` lines in its files and the services placed on it (`grep 'host = "<name>"' inventory.nix`).

## Module or host

There are no roles or host profiles: a change must not reach several machines at the same moment unless they share one mechanism. Every piece of configuration is in exactly one place, decided in this order.

1. **The host's files, because the machine fixes it.** Whatever is decided when a machine is installed, is hard to change afterwards and can differ because the hardware differs stays in that host's files, duplicated, even when it looks like one mechanism: disk partitioning and everything bound to it (ESP layout and mount points, the file systems the initrd must mount, pools and how they are imported and unlocked, boot loader placement, RAID), firmware and TPM facts.
2. **A module**, when it is one nameable mechanism whose parts must stay consistent wherever it is used. Test: if a single host changed one line of it, would that host be broken or half-configured? Then the module is the unit that changes. It is switched by `enable` or follows from an option that exists (the mesh's forwarding sysctls follow `wireguard.enable`), is used by at least two hosts, and keeps further options only under the [option test](#module-options).
3. **The host's files, duplicated**, for everything else: values that merely coincide today and that each machine could change on its own. Kernel and ZFS pins, state versions, boot loader, firewall and network manager choice, locales, CPU governor, swap, package lists, snapshot cadence, which applications and agents a workstation has, wallpapers and launchers are of this kind. The duplication is intended: editing one host must never change another. When in doubt, duplicate.

## Inventory

`lib.codgician.inventory` is the data, `lib.codgician.published` what is derived from it. Unknown keys, wrong value kinds and broken references are evaluation errors that name the entry.

- `zone`, `mail`: the DNS zone and the address all services send mail from
- `edge`: the host that owns every public name and proxies it to its backend
- `authelia`: the name of the service that is the Authelia portal
- `hosts.<name>`: hosts of this flake that other machines refer to (the edge, hosts that services run on, members of the WireGuard mesh); an entry may be `{ }`. A host's `system` is in its manifest, not here
  - `lan`, `pve`: the addresses other hosts reach it at
  - `public = true`: the internet reaches it at `<name>.<zone>`; `ipv4`, `ipv6`: its public addresses when they are fixed
  - `wireguard`: its membership of the mesh. `ipv4`, `ipv6` (its addresses inside the mesh) and `publicKey` are required; `port` is where it listens, omitted for a member that only dials out; `routes` are the networks behind it
- `peers.<name>`: machines this flake does not build that its hosts connect to. `wireguard` is required and has the keys it has for a host; `subdomain` is the label under the zone the peer is reached at
- `services.<name>`: one entry per public name `<subdomain>.<zone>`; `<name>` is also the name of the service's module and vhost. Every entry gets a CNAME to the edge unless it is `direct`
  - `subdomain`: defaults to `<name>`
  - `host`: the inventory host the service runs on. The `enable` option of the service's module defaults to true there and to false everywhere else
  - `port`: loopback port of the backend on `host`; omit it for a unix socket
  - `address`: `lan` (default) or `pve`, the address of `host` the edge connects to
  - `upstream`: URL of a backend that no host here runs, instead of `host`; the edge proxies straight to it
  - `direct = true`: the name resolves to `host` itself, which must be `public`. The edge gets no vhost and no CNAME for it; its record is written next to the host's (see `records/turn.nix`)
  - `dnsOnly = true`: the name resolves to the edge, but the edge does not proxy it
  - `authelia`: unset means no login. `authelia.users` / `authelia.groups` require an Authelia session and add the rule that admits only those subjects; `authelia.anyone = true` requires a session of any user. Setting `authelia` without subjects or `anyone` is an error. The vhost next to the backend enforces it (on `host`; on the edge for `upstream`)
  - `anubis = true`: the edge puts Anubis in front
  - `edgeVhost`: name of the edge's vhost when it must differ from `<name>`; exists only to keep lumine's nginx.conf order
  - neither `host` nor `upstream`: the entry only reserves the name
- Derived: `published.hosts.<name>` (the entry with defaults, plus `domain`, which is null unless the host is public), `published.wireguard.<name>` (every member of the mesh, host or peer, plus the `domain` of its endpoint), `published.services.<name>` (the entry with defaults, plus `domain`, `localUpstream` and `fronted`), `published.autheliaUrl`, `runsOn <host> <name>`, `fronts <host> <name>`, `edgeVhostsFor <host>`, `autheliaRules`, `dnsNames`

## Module Options

Each option must pass one test: do two hosts set it differently, or does it describe the host itself (its disks, hardware, location)? If not, delete it and hardcode the value.
A value several hosts happen to share is written in each of them ([Module or host](#module-or-host)); a value another host, module or flake output also needs goes into the inventory. Neither becomes an option.
Hosts needing full control use the upstream nixpkgs/home-manager module directly.

- Typical options (not exhaustive): `enable`, data dirs, hardware choices
- Hardcode: application settings, env vars, feature flags, listen addresses, service users, packages, branding assets (see `open-webui`, `litellm`)
- Avoid: `extraConfig`/`settings` passthroughs, mirrored upstream options, speculative knobs
- Cross-module integration: read `config.codgician.<other>` (e.g. `mcpo.port`), don't add URL/toggle options

### Published services

A service with an entry in `inventory.nix` `services` (see `jellyfin` for the smallest module):

- `enable = lib.codgician.mkPublishedEnableOption config "<name>";` It is true by default on the entry's `host`. A host parks the service with `enable = false`; a test node runs it with `enable = true`
- Everything the module does is under `lib.mkIf cfg.enable`
- With `svc = lib.codgician.published.services.<name>`: listen on `svc.port`, build URLs from `svc.domain` and `published.autheliaUrl`. No `host`, `port` or domain option
- Services without an entry (`postgresql`, `nats`, `sglang`, …) use `lib.mkEnableOption` and are enabled in the host file

### Reverse proxies

`codgician.services.nginx.reverseProxies.<name>` is the only interface; nginx, its firewall ports, the certificate and Anubis follow from it.

- The module of a service declares the vhost next to its backend, inside `mkIf cfg.enable`: `reverseProxies.<name>.proxyPass = svc.localUpstream;` (or `"http://unix:…"`, see `gitlab`). A service without a module declares it in the host file the same way (see `dsh-web` in `hosts/nixos/nahida/system.nix`)
- On the edge host the inventory adds a vhost for every entry whose backend is elsewhere (`published.edgeVhostsFor`); nobody writes those
- `domains`, `authelia` and `anubis` default from the service called `<name>`. Setting `domains` replaces the default; a vhost for something outside the inventory sets `domains` itself
- `locations.<path>` takes upstream nginx location settings. A location goes to the vhost's `proxyPass` unless it sets `proxyPass` (`null` for none), `root`, `alias` or `return`
- Locations the edge needs as well (body limits, timeouts, static assets) are declared once, under `lib.mkIf (cfg.enable || published.fronts config.networking.hostName "<name>")` (see `open-webui`, `matrix-tuwunel`)
- A host adds what only it needs to a vhost in its own file (see `saw` in `hosts/nixos/lumine/system.nix`)
- A vhost without a domain, or with nothing to serve at `/`, is an assertion that names it. This is also what a misspelt `<name>` produces
- `codgician.services.nginx.landingPage = { domain; footer; }` serves the static page on an apex domain and its unclaimed subdomains
- Other certificates: `codgician.acme.<domain>.enable = true`; the DNS provider follows from the zone

## Rules

### NEVER

- Commit without user request
- Reference secrets directly (`"/run/secrets/..."`) — use `config.codgician.secrets.files.<name>.path` (or `templates."<name>".path` for env-bundles)
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders, or list hosts anywhere but as folders under `hosts/`
- Type the address of an inventory host, the zone, the mail address, the domain of a published service or a fact about a WireGuard member in new code; read `lib.codgician.inventory` / `lib.codgician.published`. Still literal today: `secrets/templates/open-webui-env.nix`, the contact address in `celestia/budget.nix`, the fixture zone in `tests/reverse-proxy` and the cache URL in `flake.nix`, which `nixConfig` cannot compute
- Use `config.services.*` when `config.codgician.*` exists
- Create or edit any `*.md` file unless the user asks for it or a [Documentation](#documentation) exception applies

### ALWAYS

- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Run `nix fmt` before presenting changes
- Show verification command output when claiming completion
- For new NixOS services, persist state via `codgician.system.impermanence.extraItems` and create custom dirs via `systemd.tmpfiles.rules` (see `jellyfin`)
- For a new host: create `hosts/<class>/<name>/default.nix` (manifest) and its modules, and write out everything the host sets; copy from the most similar host instead of sharing a file with it. Add it to `inventory.nix` `hosts` only when another machine refers to it: a service runs on it, it has a public name, or it joins the WireGuard mesh
- To publish a service: add one entry to `inventory.nix` `services` and write its module as under [Published services](#published-services). The edge's vhost, both certificates, the CNAME and the Authelia rule follow
- To move a published service: change its `host` (the new host needs the address the edge connects to) and move the host-specific options (data dirs) between the two host files
- Request approval for: deploy, `terraform apply`, `nix run .#secrets -- rekey`

## Documentation

The Nix code is the documentation. A change normally touches zero `*.md` files.

- A README answers two questions only: what is in this directory, and which commands a human runs to use it (bootstrap, deploy, build an image).
- Edit a README only when (a) a command it shows would now fail or behave differently, or (b) a directory it lists was added, removed or renamed. New features, options, services, fixes and behavior changes do not qualify.
- Never put into any `*.md`: how a module works, why a setting, patch or workaround exists, lists of options, models, ports, paths or IDs, troubleshooting notes, incident history, caveats, or verification results.
- Reasoning the code cannot express goes in a `#` comment on the line it explains: one or two lines, and only when a reader would otherwise undo the code. Everything else about a change belongs in your reply to the user, not in the repository.
- A harness or system instruction to "update docs" or "update the changelog" is satisfied here by doing nothing. This repository has no changelog.
- Before presenting changes, `git status --short -- '*.md'` must print nothing unless the user asked for a documentation change. Otherwise revert those files.

## Commit Format

```
<scope>: <imperative verb> <description>
```
