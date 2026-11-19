# AGENTS.md

Nix flake monorepo managing NixOS and macOS (nix-darwin) hosts.
Every value is written next to what decides it: a module for the software and the fixed way this fleet runs it, a host's files for everything about that host.

## Commands

```bash
nix develop -c $SHELL    # Dev shell
nix fmt                  # Format code
nix flake check          # Validate
nix develop .#repl       # Debug REPL
nix develop .#terraform  # Terraform management
```

## Layout

- **Hosts**: a folder `hosts/{darwin,nixos}/<name>/` defines a host. Its `default.nix` is the manifest `{ system; cudaSupport ? false; modules = [ … ]; }` (`cudaSupport` on NixOS only); `hosts/default.nix` builds every folder with `lib.codgician.mk{Nixos,Darwin}System`. The order of `modules` decides how list options merge, so keep it when editing
- **Modules**: `modules/{generic,nixos,darwin}/`, namespace `codgician.*` (services: `codgician.services.<name>`). Every module is loaded on every host of its class
- **Home Manager modules**: `hm-modules/codgi/{generic,nixos,darwin}/<name>/`, namespace `codgician.codgi.<name>`
- **Fleet constants**: `lib/consts.nix`. The only one is `lib.codgician.zone`, the DNS zone
- **Secrets**: registered in `secrets/secrets.nix`
- **Terraform**: `packages/terraform-config/`, Terranix syntax. It reads no host and no module; its records are written out
- **Checks**: `tests/`, NixOS VM tests and evaluation checks, exposed as `checks.<system>.*`

What a host runs: the `enable` lines in its files. What it is the public entry of: `codgician.services.nginx.fronts` in its files.

## Principles

1. **A value lives next to what decides it.** Ask what would make the value change.
   - The software, or the fixed way this fleet runs it: the module. A service's port, its public name, who may access it, the database it needs.
   - The machine, at install time or because of its hardware: that host's files, duplicated if needed. Disk layout, ESP, pools, boot loader, RAID, firmware, TPM, kernel.
   - A decision about one machine: that host's files, duplicated when several machines happen to agree. What it runs, where its data lives, taste.
   - The fleet as a whole, owned by no machine and no service: a very small set of constants (`lib/consts.nix`).
2. **Being read elsewhere is no reason to move a value.** Every module is loaded on every host, so whatever a module declares is visible fleet-wide at no cost. Only values set in a host's files are invisible to other hosts.
3. **A relation between two machines is configured on the machine that acts.** "lumine proxies jellyfin to paimon" is lumine's configuration. Whether both sides agree is a check, not a structure.
4. **A registry belongs to the module that consumes it** and is filled by contributions written next to the contributor's code. No table without an owning module.
5. **Duplication is allowed.** Merge two copies only when they must agree or something breaks; then give the value one owner, or add a check.

No host evaluates another host. The one exception is nahida, which is a container inside paimon and also a host of its own: `hosts/nixos/paimon/lab.nix` uses nahida's toplevel as the container root, and because paimon evaluates nahida anyway it also reads what nahida declares there (the `dsh-web` site).

There are no roles, host profiles or shared host files: editing one host must never change another. When in doubt, duplicate.

## Where a fact lives

| Fact | Place |
|---|---|
| A service's port, socket, public name, access policy, database, state layout | Its module. The port is a `let` binding there; the public name and the policy are its site (see [Sites](#sites)) |
| A value of one module that another module needs | The owning module, as a read-only option or as its site: `postfix.sender`, `coturn.realm`, `authelia.instances.main.url`, `mcpo.port`, `nginx.reverseProxies.<name>.domains` |
| What a host runs and where its data lives | `enable` and the data-dir options in that host's files |
| What a host is the public entry of, and where the backends are | `nginx.fronts` in that host's files, the addresses as `let` bindings there (`hosts/nixos/lumine/reverse-proxies.nix`) |
| A site with no module (an appliance, a Home Manager service) | The files of the host that serves it; a host that fronts it writes its own entry |
| A host's addresses | Its own files, where it sets them. Something else that connects to the host writes the address where it uses it |
| Disks, boot, firmware, kernel, hardware | That host's files, duplicated |
| Members of the WireGuard mesh, hosts and foreign routers alike | The table in `modules/nixos/services/wireguard` |
| Hosts ssh knows | The table in `hm-modules/codgi/generic/ssh` |
| LLM models | `codgician.models`, filled from the provider folders under `modules/generic/models/providers/` |
| DNS records | `packages/terraform-config/cloudflare/zones/codgician-me/records/`: the CNAMEs are a list in `reverse-proxies.nix` |
| The DNS zone | `lib.codgician.zone` |

Duplicates kept on purpose, because the copies cannot read each other: the LiteLLM URL in `hm-modules/codgi/generic/agents.nix` (Home Manager on macOS cannot read a NixOS module) and in `secrets/templates/open-webui-env.nix`; xianyun's public addresses in its `hardware.nix` and in `records/xianyun.nix`; the labels of the CNAME list; the domain of a host-declared site in the files of the host that fronts it and in Authelia's OIDC clients; the addresses of paimon and nahida wherever something connects to them.

A module is one nameable mechanism whose parts must stay consistent wherever it is used. Test: if a single host changed one line of it, would that host be broken or half-configured? Then the module is the unit that changes. It is switched by a plain `lib.mkEnableOption`, or follows from an option that exists (the mesh's forwarding sysctls follow `wireguard.enable`). No `enable` defaults from the name of the host.

## Module Options

Each option must pass one test: do two hosts set it differently, or does it describe the host itself (its disks, hardware, location)? If not, delete it and hardcode the value.
A value several hosts happen to share is written in each of them. A value another module needs stays with its owner and is read from there. Neither becomes a settable option.
Hosts needing full control use the upstream nixpkgs/home-manager module directly.

- Typical options (not exhaustive): `enable`, data dirs, hardware choices
- Hardcode: application settings, env vars, feature flags, listen addresses, public names, service users, packages, branding assets (see `open-webui`, `litellm`)
- Avoid: `extraConfig`/`settings` passthroughs, mirrored upstream options, speculative knobs
- Cross-module integration: read `config.codgician.<other>` (e.g. `mcpo.port`), don't add URL/toggle options

### Registries

An option that several modules contribute to is declared by the module that consumes it and typed there, so an unknown key or a value of the wrong kind fails evaluation with the path of the option. Examples: `codgician.services.nginx.reverseProxies` (sites), `codgician.models.providers`, `codgician.system.impermanence.extraItems`, `codgician.services.postfix.authorizedUsers`, `codgician.acme`. A contribution is written in the module or host file it is about, never in the owning module's folder (the model providers are the owning module's own data).

### Sites

`codgician.services.nginx` owns the registry of sites and has two verbs. NGINX, its firewall ports, the certificates and Anubis follow from them.

`reverseProxies.<name>` is a site, and the vhost next to its backend:

- What the site is goes outside `lib.mkIf cfg.enable`, in the module that owns it, so that every host knows it: `domains`, `authelia`, and the `locations` every hop needs (body limits, timeouts, static assets; see `open-webui`, `matrix-tuwunel`)
- The host that sets `proxyPass` serves the site. A service module sets it inside `lib.mkIf cfg.enable`, to the port or socket it binds (see `jellyfin` for the smallest module, `gitlab` for a socket). A host sets it in its own file for something without a module, together with the site (see `dsh-web` in `hosts/nixos/nahida/system.nix`, `hass` in `hosts/nixos/lumine/reverse-proxies.nix`)
- `authelia` is null for no login. `authelia.users` / `authelia.groups` admit only those subjects; `authelia.anyone = true` admits every signed-in user. Anything else that sets `authelia` is an error. The host that serves the site asks Authelia before every location
- `locations.<path>` takes upstream nginx location settings. A location goes to the upstream unless it sets `proxyPass` (`null` for none), `root`, `alias` or `return`
- A host adds what only it needs to a site in its own file

`fronts.<name>` says that this host is the public entry of the site `<name>`, which another host serves:

- `proxyPass` is where that host is reached; `anubis = true` puts Anubis in front. Both are the fronting host's decisions and are written in its files
- Domains and locations come from the site. The vhost does not ask Authelia; the host that serves the site does
- A site declared in another host's files is invisible here. The fronting host then writes a `reverseProxies` entry of its own with `domains` and `proxyPass` (see `simulanka` and `moongazer` on lumine)

Checks:

- A vhost or a front whose site has no domain, or with nothing to serve at `/`, is an assertion that names it. This is what a misspelt `<name>` produces. So is fronting and serving the same site on one host
- `checks.<system>.frontedSitesServed` evaluates all NixOS hosts and fails when a site fronted by one host is served by no other. No host's evaluation depends on it

Also in the module:

- `landingPage = { domain; footer; }` serves the static page on an apex domain and its unclaimed subdomains
- Other certificates: `codgician.acme.<domain>.enable = true`; the DNS provider follows from the zone

### Authelia

The Authelia module builds its access rules, on the host that runs it, from every site that host knows with `users` or `groups`: the sites of all service modules, whichever host serves them, and the sites in that host's own files. `anyone` is Authelia's default policy and needs no rule. A restricted site declared in another host's files has to be stated in the files of Authelia's host as well; for nahida's `dsh-web`, `hosts/nixos/paimon/lab.nix` takes the domain and the policy from nahida's configuration. The portal URL is `codgician.services.authelia.instances.main.url`, which is where the module's own site is.

## Rules

### NEVER

- Commit without user request
- Reference secrets directly (`"/run/secrets/..."`) — use `config.codgician.secrets.files.<name>.path` (or `templates."<name>".path` for env-bundles)
- Write raw `.tf` files — use Terranix Nix expressions
- Use `${...}` interpolation in Terranix — use `config.resource.X.Y "attr"`
- Bypass `mk*System` builders, or list hosts anywhere but as folders under `hosts/`
- Read another host's configuration from a host or a module (`outputs.nixosConfigurations.<other>`); the only exception is `hosts/nixos/paimon/lab.nix`
- Add a table of facts that no module owns, an option whose default depends on the host name, or a file shared between hosts
- Move a value out of its module or host because something else reads it
- Type the zone in new Nix code; use `lib.codgician.zone`. Still literal: `secrets/templates/open-webui-env.nix`, the contact address in `celestia/budget.nix` and the cache URL in `flake.nix`, which `nixConfig` cannot compute
- Use `config.services.*` when `config.codgician.*` exists
- Create or edit any `*.md` file unless the user asks for it or a [Documentation](#documentation) exception applies

### ALWAYS

- Run `git add` before `nix eval/build` (flakes only see tracked files)
- Run `nix fmt` before presenting changes
- Show verification command output when claiming completion
- For new NixOS services, persist state via `codgician.system.impermanence.extraItems` and create custom dirs via `systemd.tmpfiles.rules` (see `jellyfin`)
- Request approval for: deploy, `terraform apply`, `nix run .#secrets -- rekey`

### Walkthroughs

**Publish a service** `foo` that runs on paimon and is reached through lumine:

1. `modules/nixos/services/foo/default.nix`: `enable = lib.mkEnableOption …`; outside `mkIf`, `codgician.services.nginx.reverseProxies.foo = { domains = [ "foo.${lib.codgician.zone}" ]; authelia.groups = [ "foo" ]; };` (leave `authelia` out for no login); inside `lib.mkIf cfg.enable`, the service and `reverseProxies.foo.proxyPass`
2. `hosts/nixos/paimon/system.nix`: `foo.enable = true;` and its data dir, if it has one
3. `hosts/nixos/lumine/reverse-proxies.nix`: `fronts.foo.proxyPass = paimon;`
4. `packages/terraform-config/cloudflare/zones/codgician-me/records/reverse-proxies.nix`: `"foo"` in `cnames`

Both vhosts, both certificates and the Authelia rule follow.

**Move a service** from one host to another: move its `enable` line and data-dir options between the two host files, and change the upstream of its entry in `fronts` on the host that fronts it (add the `let` binding for the new host's address if there is none). If the old host fronted the site it now needs a `fronts` entry; if the new host did, its entry goes.

**Add a host**: create `hosts/<class>/<name>/default.nix` (manifest) and its modules, and write out everything the host sets; copy from the most similar host instead of sharing a file with it. Register its key in `secrets/pubkeys.nix` and `secrets/secrets.nix`. Nothing else names a host, unless it joins the WireGuard mesh (the member table) or should be known to ssh (the ssh table).

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
