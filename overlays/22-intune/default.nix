{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (
    final: prev:
    let
      fakeUbuntuOsRelease = prev.writeText "fake-os-release-ubuntu" ''
        PRETTY_NAME="Ubuntu 26.04 LTS"
        NAME="Ubuntu"
        VERSION_ID="26.04"
        VERSION="26.04 (Resolute Raccoon)"
        VERSION_CODENAME=resolute
        ID=ubuntu
        ID_LIKE=debian
        HOME_URL="https://www.ubuntu.com/"
        SUPPORT_URL="https://help.ubuntu.com/"
        BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
        PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
        UBUNTU_CODENAME=resolute
        LOGO=ubuntu-logo
      '';

      intune-portal-unwrapped = prev.nur.repos.codgician.intune-portal;

      mkBwrapWrapper =
        name:
        prev.writeShellScript "${name}-wrapper" ''
          OS_RELEASE_TARGET=$(${prev.coreutils}/bin/readlink -f /etc/os-release)
          exec ${prev.bubblewrap}/bin/bwrap \
            --bind / / \
            --ro-bind ${fakeUbuntuOsRelease} "$OS_RELEASE_TARGET" \
            --dev-bind /dev /dev \
            --proc /proc \
            --die-with-parent \
            -- ${intune-portal-unwrapped}/bin/${name} "$@"
        '';

      desktopItem = prev.makeDesktopItem {
        name = "intune-portal";
        desktopName = "Microsoft Intune";
        comment = "Microsoft Intune";
        exec = "env INTUNE_NO_LOG_STDOUT=1 intune-portal";
        icon = "intune";
        terminal = false;
      };

      mdatp-unwrapped = prev.nur.repos.codgician.mdatp;
      mdatpRoot = "/opt/microsoft/mdatp";

      # mdatp hard-codes /opt/microsoft/mdatp, the FHS loader and a Debian-like
      # userland (it runs bundled #!/bin/bash scripts whose hashes it verifies),
      # so run it unmodified in an FHS sandbox that reports Ubuntu.
      mdatp-fhs = prev.buildFHSEnv {
        pname = "mdatp-fhs";
        inherit (mdatp-unwrapped) version;
        targetPkgs =
          pkgs: with pkgs; [
            acl
            dmidecode
            e2fsprogs
            elfutils
            gnupg
            iproute2
            iptables
            kmod
            libcap
            # The eBPF sensor attaches uprobes to libpam from the FHS library path.
            pam
            procps
            python3
            sqlite
            systemd
            util-linux
            zlib
          ];
        runScript = "";
        # Services start the sandbox in the background and exit (Type=forking).
        dieWithParent = false;
        extraBuildCommands = ''
          mkdir -p $out${mdatpRoot}
          ln -s ${fakeUbuntuOsRelease} $out/etc/os-release
          # Report the host's login and PAM policy rather than shadow's defaults.
          chmod u+w $out/etc
          rm -rf $out/etc/login.defs $out/etc/pam.d
        '';
        extraPreBwrapCmds = ''
          # Show the host /etc as-is so mdatp inspects the real system
          # configuration; the FHS environment only supplies its own entries.
          for i in /etc/*; do
            name=''${i#/etc/}
            if [[ $name == opt || -e ${mdatp-fhs.fhsenv}/etc/$name || -L ${mdatp-fhs.fhsenv}/etc/$name ]]; then
              continue
            fi
            symlinks+=(--symlink "/.host-etc/$name" "$i")
            # Also skip buildFHSEnv's own binds of nested entries (ssl/certs).
            etc_ignored+=("$i" "$i"/*)
          done

          # The daemon greps /boot/config-$(uname -r) for eBPF prerequisites, which
          # NixOS does not install. Rebuild /boot from the host's entries on a
          # tmpfs and add the file there instead of writing to the ESP (vfat
          # rules out an overlay).
          boot_args=()
          kernel_config=/boot/config-$(${prev.coreutils}/bin/uname -r)
          if [[ $EUID == 0 && ! -e $kernel_config && -r /proc/config.gz ]]; then
            exec {kernel_config_fd}< <(${prev.gzip}/bin/zcat /proc/config.gz)
            boot_args=(--tmpfs /boot)
            for i in /boot/*; do
              if [[ -e $i ]]; then
                boot_args+=(--bind "$i" "$i")
              fi
            done
            boot_args+=(--file "$kernel_config_fd" "$kernel_config")
          fi
        '';
        extraBwrapArgs = [
          "--ro-bind ${mdatp-unwrapped}${mdatpRoot} ${mdatpRoot}"
          "--bind-try /etc/opt /etc/opt"
          ''"''${boot_args[@]}"''
        ];
      };
    in
    {
      intune-portal = prev.symlinkJoin {
        name = "intune-portal-${intune-portal-unwrapped.version}";
        paths = [ intune-portal-unwrapped ];
        postBuild = ''
          rm $out/bin/intune-portal $out/bin/intune-agent
          ln -s ${mkBwrapWrapper "intune-portal"} $out/bin/intune-portal
          ln -s ${mkBwrapWrapper "intune-agent"} $out/bin/intune-agent

          # Replace .desktop with version pointing to wrapped binary
          rm $out/share/applications/intune-portal.desktop
          ln -s ${desktopItem}/share/applications/intune-portal.desktop $out/share/applications/intune-portal.desktop
        '';
      };

      inherit intune-portal-unwrapped fakeUbuntuOsRelease mdatp-unwrapped;

      mdatp =
        prev.runCommand "mdatp-${mdatp-unwrapped.version}"
          {
            passthru = {
              unwrapped = mdatp-unwrapped;
              fhs = mdatp-fhs;
            };
            inherit (mdatp-unwrapped) meta;
          }
          ''
            mkdir -p $out/bin $out/libexec/mdatp
            ln -s ${mdatp-fhs}/bin/mdatp-fhs $out/libexec/mdatp/fhs
            cat > $out/bin/mdatp <<EOF
            #!${prev.runtimeShell}
            exec ${mdatp-fhs}/bin/mdatp-fhs ${mdatpRoot}/sbin/wdavdaemonclient "\$@"
            EOF
            chmod +x $out/bin/mdatp
            ln -s ${mdatp-unwrapped}/share $out/share
          '';
    }
  )

  (fromUnstable [ "microsoft-identity-broker" ])
]
