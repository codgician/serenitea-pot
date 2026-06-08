{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:

let
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
  system = pkgs.stdenv.hostPlatform.system;

  fixtures = ./fixtures;

  commonDefaults = {
    imports = lib.codgician.mkNixosModules system { };
    nixpkgs.overlays = pkgs.overlays;
    _module.args = {
      inherit inputs outputs system;
    };
  };

  machine =
    { lib, config, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      # Point sops-nix at the throwaway fixture key as a NIX STORE PATH. The
      # store is mounted read-only at every activation phase, so the key is
      # available even during the early `setupSecretsForUsers` step (which runs
      # before /etc exists). A real impermanence host satisfies the same
      # constraint via /persist/etc/ssh/ssh_host_ed25519_key (neededForBoot).
      # Seeding via environment.etc/services.openssh.hostKeys is too late: those
      # run in the `etc` activation script, after secrets-for-users.
      sops.age.sshKeyPaths = lib.mkForce [ (fixtures + "/ssh_host_ed25519_key") ];

      users.users.root = {
        initialPassword = "root";
        hashedPasswordFile = lib.mkForce null;
      };

      # A regular service user owning a secret it does not create itself, to
      # prove sops chowns correctly for non-root, service-created owners.
      users.groups.testsvc = { };
      users.users.testsvc = {
        isSystemUser = true;
        group = "testsvc";
      };

      # A login user whose password comes from a neededForUsers secret, proving
      # the early-decrypt path materializes the hash before user creation.
      users.users.loginuser = {
        isNormalUser = true;
        hashedPasswordFile = config.codgician.secrets.files.test-password.path;
      };

      codgician.secrets.files = {
        test-secret = {
          sopsFile = fixtures + "/test-secret";
          format = "binary";
          owner = "root";
          group = "root";
          mode = "0440";
        };

        test-service-secret = {
          sopsFile = fixtures + "/test-service-secret";
          format = "binary";
          owner = "testsvc";
          group = "testsvc";
          mode = "0400";
        };

        test-password = {
          sopsFile = fixtures + "/test-password";
          format = "binary";
          neededForUsers = true;
        };
      };

      # Prove the host template path end to end: two raw values composed into a
      # dotenv file via placeholder substitution at activation. This mirrors
      # exactly what the secrets module generates for an env-bundle template
      # (sops.secrets.<ref> + sops.templates.<name> using sops.placeholder).
      sops.secrets.test-api-key.sopsFile = fixtures + "/values/test-api-key";
      sops.secrets.test-db-pass.sopsFile = fixtures + "/values/test-db-pass";
      sops.secrets.test-api-key.format = "binary";
      sops.secrets.test-db-pass.format = "binary";
      sops.templates."test.env" = {
        content = ''
          API_KEY=${config.sops.placeholder.test-api-key}
          DB_PASS=${config.sops.placeholder.test-db-pass}
        '';
        owner = "testsvc";
      };
    };
in
{
  sopsHostDecrypt = nixos-lib.runTest {
    name = "secrets-sops-host-decrypt";
    hostPkgs = pkgs;
    defaults = commonDefaults;
    nodes.machine = machine;

    testScript = ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      with subtest("sops-nix decrypts the fixture at activation"):
          content = machine.succeed("cat /run/secrets/test-secret").strip()
          assert content == "mock-secret-value-12345", f"unexpected content: {content!r}"

      with subtest("decrypted secret has the declared owner, group, and mode"):
          owner = machine.succeed("stat -c '%U' /run/secrets/test-secret").strip()
          group = machine.succeed("stat -c '%G' /run/secrets/test-secret").strip()
          mode = machine.succeed("stat -c '%a' /run/secrets/test-secret").strip()
          assert owner == "root", f"owner: {owner}"
          assert group == "root", f"group: {group}"
          assert mode == "440", f"mode: {mode}"

      with subtest("non-root service-user-owned secret is chowned correctly"):
          owner = machine.succeed("stat -c '%U' /run/secrets/test-service-secret").strip()
          group = machine.succeed("stat -c '%G' /run/secrets/test-service-secret").strip()
          assert owner == "testsvc", f"owner: {owner}"
          assert group == "testsvc", f"group: {group}"
          machine.succeed("runuser -u testsvc -- cat /run/secrets/test-service-secret")

      with subtest("neededForUsers secret decrypts to /run/secrets-for-users"):
          machine.succeed("test -e /run/secrets-for-users/test-password")
          owner = machine.succeed("stat -c '%U' /run/secrets-for-users/test-password").strip()
          assert owner == "root", f"neededForUsers owner must be root: {owner}"

      with subtest("login user was created with the early-decrypted password hash"):
          machine.succeed("id loginuser")
          shadow = machine.succeed("getent shadow loginuser").strip()
          assert "$6$" in shadow, f"login user has no sha512 hash: {shadow!r}"

      with subtest("login user can actually authenticate with the password"):
          machine.succeed(
              "echo 'test-password-123' | su loginuser -c 'echo AUTH_OK' | grep AUTH_OK"
          )

      with subtest("host template renders composed env file via placeholder substitution"):
          rendered = machine.succeed("cat /run/secrets/rendered/test.env")
          assert "API_KEY=sk-test-12345" in rendered, f"api key not substituted: {rendered!r}"
          assert "DB_PASS=dbpass-67890" in rendered, f"db pass not substituted: {rendered!r}"

      with subtest("rendered template has the declared owner"):
          owner = machine.succeed("stat -c '%U' /run/secrets/rendered/test.env").strip()
          assert owner == "testsvc", f"owner: {owner}"
    '';
  };
}
