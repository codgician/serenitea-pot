{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "ovis-relay";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;

  ovis = pkgs.llm-agents.ovis;

  # The relay ships in Ovis' source but not in its package; its dependencies resolve
  # through the packaged node_modules.
  relay = pkgs.runCommand "ovis-relay-${ovis.version}" { } ''
    mkdir -p $out/share/ovis-relay
    cp -r ${ovis.src}/relay $out/share/ovis-relay/relay
    ln -s ${ovis}/share/ovis/shared $out/share/ovis-relay/shared
    ln -s ${ovis}/share/ovis/node_modules $out/share/ovis-relay/node_modules
  '';

  # The hosted app (`build:shell`), built from the same Ovis release the PCs run, with
  # nginx header snippets derived from the same sources as upstream's `_headers`.
  shell = ovis.overrideAttrs (old: {
    pname = "ovis-shell";
    # Sign-in only works on app.ovis.sh, so the self-hosted app offers none.
    env = (old.env or { }) // {
      OVIS_ACCOUNT_SERVICE_URL = "off";
    };

    buildPhase = ''
      runHook preBuild
      bun run build:shell
      cat > nginx-headers.ts <<'EOF'
      import { mkdirSync, writeFileSync } from "node:fs";
      import { IMMUTABLE_CACHE, REVALIDATE, shellContentSecurityPolicy } from "./server/static.ts";
      import { pagePolicy } from "./server/file-view.ts";
      import { REGIONAL_APPS } from "./shared/relay-regions.ts";
      const header = (name: string, value: string) => {
        if (value.includes('"')) throw new Error(`unexpected quote in ''${name}`);
        return `add_header ''${name} "''${value}" always;\n`;
      };
      mkdirSync("nginx", { recursive: true });
      writeFileSync("nginx/csp-shell.conf", header("Content-Security-Policy", shellContentSecurityPolicy(Object.values(REGIONAL_APPS))));
      writeFileSync("nginx/csp-render.conf", header("Content-Security-Policy", pagePolicy(null)));
      writeFileSync("nginx/cache-immutable.conf", header("Cache-Control", IMMUTABLE_CACHE));
      writeFileSync("nginx/cache-revalidate.conf", header("Cache-Control", REVALIDATE));
      EOF
      bun nginx-headers.ts
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share
      cp -r dist-shell $out/share/ovis-shell
      rm $out/share/ovis-shell/_headers $out/share/ovis-shell/_redirects
      cp -r nginx $out/share/ovis-shell-nginx
      runHook postInstall
    '';

    dontFixup = true;
  });

  root = "${shell}/share/ovis-shell";
  include = name: "include ${shell}/share/ovis-shell-nginx/${name}.conf;";
  scope = "/s/[0-9a-f]{32}";

  # Static location of the hosted app: rewrites and headers mirror upstream's
  # `_redirects` and `_headers` (scripts/shell-build.ts).
  staticLocation =
    {
      tryFiles ? null,
      csp ? "csp-shell",
      cache ? null,
      extraConfig ? "",
    }:
    {
      authelia.enable = false;
      passthru = {
        inherit root tryFiles;
        extraConfig =
          include csp + lib.optionalString (cache != null) "\n${include cache}" + "\n" + extraConfig;
      };
    };

  relayLocation = {
    authelia.enable = false;
    passthru = {
      inherit (cfg.reverseProxy) proxyPass;
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_buffering off;
      '';
    };
  };
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "Ovis relay and self-hosted Ovis app";

    port = lib.mkOption {
      type = types.port;
      default = 8787;
      description = "Port for the Ovis relay to listen on (loopback only).";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      systemd.services.${serviceName} = {
        description = "Ovis relay";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          # Every connection arrives from nginx, so per-address budgets cover all users.
          RELAY_PER_ADDRESS_PER_MINUTE = "600";
          RELAY_MAX_SOCKETS_PER_ADDRESS = "1024";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.bun} ${relay}/share/ovis-relay/relay/bun.ts --port ${toString cfg.port} --hostname 127.0.0.1";
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = "5s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          LockPersonality = true;
        };
      };
    })

    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
        extraVhostConfig.locations = {
          # Relay
          "= /health" = relayLocation;
          "/v1/" = relayLocation;

          # Hosted app
          "/" = lib.recursiveUpdate (staticLocation { tryFiles = "$uri =404"; }) {
            passthru.proxyPass = lib.mkForce null;
          };
          "= /" = staticLocation {
            tryFiles = "/index.html =404";
            cache = "cache-revalidate";
          };
          "~ ^/(index\\.html|sw\\.js|manifest\\.webmanifest)$" = staticLocation {
            cache = "cache-revalidate";
          };
          "/assets/" = staticLocation { cache = "cache-immutable"; };
          "/.well-known/" = staticLocation { extraConfig = "default_type application/json;"; };
          # Quote regexes containing braces so nginx does not parse them as blocks.
          "~ \"^(${scope})$\"" = staticLocation {
            # Redirect from the validated capture, not the decoded and untrusted $uri.
            extraConfig = "return 301 $1/;";
          };
          "~ \"^${scope}/manifest\\.webmanifest$\"" = staticLocation {
            tryFiles = "/manifest.webmanifest =404";
            cache = "cache-revalidate";
          };
          "~ \"^${scope}/sw\\.js$\"" = staticLocation {
            tryFiles = "/sw.js =404";
            cache = "cache-revalidate";
          };
          "~ \"^${scope}/~render$\"" = staticLocation {
            tryFiles = "/render.html =404";
            csp = "csp-render";
            cache = "cache-revalidate";
          };
          "/s/" = staticLocation {
            tryFiles = "/index.html =404";
            cache = "cache-revalidate";
          };
        };
      };
    }
  ];
}
