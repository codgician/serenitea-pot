# AGENTS.md

Nix flake monorepo managing NixOS and macOS (nix-darwin) hosts.
Modules hold one opinionated config shared across hosts; hosts supply only what differs.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform  # Terraform management
```

## Layout

- **Inventory**: `inventory.nix`, plain data and the only place a cross-host fact is typed: every host (`system`, `cudaSupport`, `roles`, addresses) and every published name (`subdomain`, backend `host` + `port` or `upstream`, `edge`, `authelia`, `anubis`). `lib.codgician.inventory` is the data; `lib.codgician.published` (`lib/inventory.nix`) derives `services.<name>.{domain,port,host,…}`, `vhostsFor <host>`, `autheliaRules`, `edgeNames` and `autheliaUrl`
- **Hosts**: `hosts/default.nix` builds every configuration from the inventory with `lib.codgician.mk{Nixos,Darwin}System`. `hosts/{darwin,nixos}/<name>/default.nix` is that host's ordered module list (order decides how list options merge); its files hold only what is unique to the machine
- **Roles**: `hosts/roles/<role>.nix`, plain config without options: `common` (every host), `nixos` / `darwin` (every host of the class), and the roles a host lists in the inventory (`desktop`, `edge`)
- **Modules**: `modules/{generic,nixos,darwin}/`, namespace `codgician.*` (services: `codgician.services.<name>`)
- **Home Manager modules**: `hm-modules/codgi/{generic,nixos,darwin}/<name>/`, namespace `codgician.codgi.<name>`
- **Secrets**: registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/`, Terranix syntax; the CNAMEs of published names come from `lib.codgician.published.edgeNames`

## Module Options

Each option must pass one test: does its value differ between hosts? If not, hardcode it.
A value shared by a group of hosts goes into that group's role; a value another host, module or flake output also needs goes into the inventory. Neither becomes an option.
Hosts needing full control use the upstream nixpkgs/home-manager module directly.

- Typical options (not exhaustive): `enable`, data dirs, `package`, hardware choices
- Hardcode: application settings, env vars, feature flags, listen addresses (see `open-webui`, `claude-code`)
- Avoid: `extraConfig`/`settings` passthroughs, mirrored upstream options, speculative knobs
- Published services (anything in `inventory.nix` `services`) have no `enable`, `host`, `port` or domain option. With `svc = lib.codgician.published.services.<name>`: the module is active under `lib.mkIf (svc.host == config.networking.hostName)`, listens on `svc.port`, and builds URLs from `svc.domain` and `published.autheliaUrl` (see `jellyfin`, `open-webui`). Services nobody else reaches (`postgresql`, `nats`, …) keep `enable` and are turned on by the host
- Reverse proxy: never declare a vhost for a published service. `codgician.services.nginx.reverseProxies.<name>` already exists on its `host` (root location → `127.0.0.1:<port>`, Authelia check) and on its `edge` (root location → the backend, Anubis). A module only adds to it: `locations.<path>` for locations and nginx directives, outside its host gate when the edge needs them as well (see `open-webui`), and `proxyPass = lib.mkDefault "http://unix:…"` when the backend has no TCP port (see `gitlab`). Host-only details (a secret include, a static site) are added the same way in the host file
- Cross-module integration: read `config.codgician.<other>` (e.g. `mcpo.port`), don't add URL/toggle options

## Rules

### NEVER

- Commit without user request
- Reference secrets directly (`"/run/secrets/..."`) — use `config.codgician.secrets.files.<name>.path` (or `templates."<name>".path` for env-bundles)
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders, or add a host anywhere but `inventory.nix`
- Type a host name, a LAN address or a service domain outside `inventory.nix`; read it from `lib.codgician.inventory` / `lib.codgician.published`
- Use `config.services.*` when `config.codgician.*` exists
- Create or edit any `*.md` file unless the user asks for it or a [Documentation](#documentation) exception applies

### ALWAYS

- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Run `nix fmt` before presenting changes
- Show verification command output when claiming completion
- For new NixOS services, persist state via `codgician.system.impermanence.extraItems` and create custom dirs via `systemd.tmpfiles.rules` (see `jellyfin`)
- For a new host: add it to `inventory.nix` (system, roles) and create `hosts/<class>/<name>/default.nix` with its module list; do not repeat what its roles already set
- For a new published service: add one entry to `inventory.nix`; the vhosts on backend and edge, the certificate, the DNS record and the Authelia rule follow from it
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
