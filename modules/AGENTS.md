# Modules, overlays and services

Read the root `AGENTS.md` first; this file adds what you need when you change modules, overlays or where a service runs.

## A module

- One nameable mechanism whose parts must stay consistent: if a single host changed one line of it, would that host be half-configured? Install-time and hardware configuration never becomes a module; it stays in each host.
- Every module has a plain `enable` (`lib.mkEnableOption`), and an optional part a host may go without has its own `enable`. Never switched by the host's name. Only a helper that adds configuration to other modules and switches nothing on has none.
- An option exists only if two hosts set it differently or it describes the host (data dirs, hardware); `enable` options are exempt from this test. Hardcode the rest: settings, env vars, listen addresses, public names, service users. No `extraConfig`/`settings` passthroughs or mirrors of upstream options. This test decides what a new option may be; it never justifies deleting an existing option or capability.
- Exception: a module that installs or runs software keeps a `package` option (`lib.mkPackageOption`, or `image` for a container), defaulting to what hosts use, so one host can run a different build.
- Whether a host uses a module, one of its optional parts or its `package` option today is no reason to delete any of them.
- A value another module needs stays with its owner and is read from `config.codgician.<owner>`.
- State: persist it with `codgician.system.impermanence.extraItems`, create custom dirs with `systemd.tmpfiles.rules` (see `modules/nixos/services/jellyfin`).
- An option several modules contribute to (`nginx.reverseProxies`, `impermanence.extraItems`, `codgician.acme`) is declared and typed by the module that consumes it; contributions are written next to the code they are about.

## Overlays

An overlay that takes a package from another package set or overrides it covers the whole package family (`vscode` with `vscode-extensions`, `vscode-fhs`, `vscode-with-extensions`, `vscodium`, `vscodium-fhs`). Whether hosts use a member today is no reason to leave it out or remove an overlay.

`pkgs.unstable` is the package set an unstable host uses; in an unstable set it is the set itself. An overlay takes packages from it only through `fromUnstable` (`fromUnstable [ … ]`, `.python`, `.kernel`), as the last part of a `lib.composeManyExtensions` list, and patches a package it takes as a plain `prev.<name>` override before that part; it never defines a name from `pkgs.unstable.<same name>`.

## Sites (`codgician.services.nginx.reverseProxies.<name>`)

One option per site; the option descriptions in `modules/nixos/services/nginx/default.nix` define it.

- The module that owns the service declares what the site is outside `lib.mkIf cfg.enable`, so every host knows it: `domains` (from `lib.codgician.zone`), `authelia`, and locations every hop needs. A site with no module goes in `modules/nixos/services/nginx/sites.nix`.
- Every host that sets `proxyPass` gets a vhost and a certificate, and asks Authelia according to the site's policy. The module sets the local upstream inside `mkIf cfg.enable`; a host that is the public entry for a site served elsewhere sets `proxyPass` to that host in its own files (lumine: `hosts/nixos/lumine/reverse-proxies.nix`). `anubis = true` is the entry host's decision.
- `authelia.users` / `authelia.groups` restrict, `authelia.anyone = true` admits any signed-in user, unset means no login. Authelia builds its rules from these.

## Walkthroughs

**Publish a service** `foo` on paimon, public through lumine:

1. `modules/nixos/services/foo/default.nix`: `enable`; outside `mkIf`, `codgician.services.nginx.reverseProxies.foo = { domains = [ "foo.${lib.codgician.zone}" ]; authelia.groups = [ … ]; };`; inside `mkIf`, the service and `reverseProxies.foo.proxyPass = "http://127.0.0.1:<port>";`
1. `hosts/nixos/paimon/system.nix`: `foo.enable = true;`
1. `hosts/nixos/lumine/reverse-proxies.nix`: `foo.proxyPass = paimon;` in `reverseProxies`
1. `packages/terraform-config/cloudflare/zones/codgician-me/records/reverse-proxies.nix`: `"foo"` in `cnames`

**Move a service**: move its `enable` line and data-dir options between the two hosts' files, and point the public entry's `proxyPass` at the new host (a `let` binding for its address in that file).

Intentional copies, because they cannot read each other: backend addresses wherever something connects to a host; the labels of the CNAME list; the LiteLLM URL in `hm-modules/codgi/generic/agents.nix` and `secrets/templates/open-webui-env.nix`; xianyun's public addresses in its `hardware.nix` and `records/xianyun.nix`.
