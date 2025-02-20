{
  lib,
  pkgs,
  outputs,
  ...
}:

let
  hostNames = builtins.attrNames (
    lib.filterAttrs (
      k: v: builtins.hasAttr "diskoImagesScript" v.config.system.build
    ) outputs.nixosConfigurations
  );
in
{
  type = "app";
  meta = {
    description = "Utility for creating disk images with predefined ssh keys";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication rec {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [
        coreutils
        qemu-utils
        openssh
      ];

      text = ''
        # Map image format extension to qemu image type arg
        declare -A formats=( \
          ["vhd"]="vpc" \
          ["raw"]="raw" \
          ["vdi"]="vdi" \
          ["vmdk"]="vmdk" \
          ["qed"]="qed" \
          ["qcow2"]="qcow2" \
        )

        function log_verbose() {
          [ "$VERBOSE" ] && echo "[VERBOSE] $*"
        }

        function warn() {
          printf '%s\n' "$*" >&2
        }

        function err() {
          warn "$*"
          exit 1
        }

        # Display help message
        function show_help {
          echo '${name} - utility for creating disk images.'
          echo ' '
          echo 'Usage: ${name} [options] hostName'
          echo ' '
          echo 'Options:'
          echo ' '
          echo ' -h --help            Show this screen'
          echo ' -v --verbose         Print verbose logs'
          echo ' -f --format          Output disk format, possible values:'
          echo "                      $(for i in "''${!formats[@]}"; do echo -n " $i"; done)"
          echo ' -o --output          Folder containing generated disk images,'
          echo '                      defaults to current directory'
          echo ' --fixed-size         Generate image with fixed size (for Azure compatibility)'
          echo ' -priv --private-key  Path to ed25519 ssh private key'
          echo ' --ssh-dir            Path to directory that stores ssh keys on host,'
          echo '                      defaults to /etc/ssh'
          echo ' -m --build-memory    Memory size of virtual machine used for building image (MB),'
          echo '                      defaults to 2048'
          echo ' '
          echo 'Available host names:'
          echo ' '
          echo ' ${builtins.concatStringsSep " " hostNames}'
          echo ' '
        }

        if test $# -eq 0; then
          show_help
          exit 1 
        fi

        imgfmt="raw"
        qemuimg_extra_args=""
        output_path=$(pwd)
        ssh_dir='/etc/ssh'
        mem_size=2048

        while test $# -gt 0; do
          case "$1" in
            -h|--help)
              show_help
              exit 0
              ;;
            -v|--verbose)
              export VERBOSE=1
              ;;
            -f|--format)
              shift
              [[ ! -v formats["$1"] ]] && err "Unrecognized image format: $1"
              imgfmt=$1
              log_verbose "Image format: $imgfmt"
              ;;
            --fixed-size)
              qemuimg_extra_args+=" -o subformat=fixed,force_size"
              ;;
            -o|--output)
              shift
              [[ ! -d $1 ]] && err "Output path not existing: $1"
              output_path=$1
              ;;
            -m|--build-memory)
              shift
              [[ -z $1 ]] && err "Build memory is not a number: $1"
              mem_size=$1
              ;;
            -priv|--private)
              shift
              privkey_path=$1

              # Ensure file exists
              [[ ! -f "$privkey_path" ]] && err "$privkey_path does not exist."

              # Ensure the key is ed25519
              keytype=$(ssh-keygen -l -f "$privkey_path" | awk '{print $4}')
              [[ $keytype != "(ED25519)" ]] && err "Private key is not of type ED25519"

              # Extract public key from private key
              if ! pubkey=$(ssh-keygen -y -f "$privkey_path"); then
                err "Failed to extract public key from private key"
              fi
              
              log_verbose "Extracted public key: $pubkey"
              ;;
            --ssh-dir)
              shift
              ssh_dir=$1
              ;;
            *)
              if [[ $1 == -* ]]; then 
                warn "Unrecognized option: $1"
                echo ""
                show_help
                exit 1
              else
                supported=("${builtins.concatStringsSep ''" "'' hostNames}")
                hostname=$1
                found=false
                for item in "''${supported[@]}"; do
                  if [[ $hostname == "$item" ]]; then
                    found=true
                    break
                  fi
                done
                if $found; then
                  log_verbose "Supported host: $hostname"
                else
                  err "Unsupported host name: $hostname"
                fi
              fi
              ;;
          esac
          shift
        done

        # Check args
        [[ -z $privkey_path ]] && err "Private key must be provided."
        [[ -z $hostname ]] && err "Host name must be specified."
        log_verbose "Extra args for qemu-img: $qemuimg_extra_args"
        log_verbose "SSH directory on host: $ssh_dir"
        log_verbose "Output path: $output_path"
        log_verbose "Build memory: $mem_size"

        # Build imaging script for provided hostname
        if ! nix build .#nixosConfigurations."$hostname".config.system.build.diskoImagesScript; then
          err "Failed to build disko script"
        fi

        # Write public key to temp dir
        tempdir=$(mktemp -d)
        log_verbose "Created temp folder: $tempdir"
        cp "$privkey_path" "$tempdir/ssh_host_ed25519_key"
        privkey_path="$tempdir/ssh_host_ed25519_key"
        pubkey_path="$tempdir/ssh_host_ed25519_key.pub"
        echo "$pubkey" > "$pubkey_path"

        # Build image
        echo "Building image for $hostname ..."
        script=$(readlink -f ./result)
        cd "$tempdir"
        if ! $script --build-memory "$mem_size" \
          --post-format-files "$privkey_path" "$ssh_dir/ssh_host_ed25519_key" \
          --post-format-files "$pubkey_path" "$ssh_dir/ssh_host_ed25519_key.pub";
        then 
          err "Failed to build image"
        fi

        # Convert built image
        mkdir "$tempdir/result"
        if [[ $imgfmt == "raw" ]]; then
          for file in *.raw; do
            mv "$file" "$output_path/$file"
          done
        else
          echo "Converting built image to target format $imgfmt ..."
          for file in *.raw; do
            qemu-img convert -f raw "$qemuimg_extra_args" -O "''${formats[$imgfmt]}" "$file" "$output_path/''${file::-4}.$imgfmt"
          done
        fi

        # Clean up temp dir
        echo 'Cleaning up ...'
        cd "$output_path"
        rm -rf "$tempdir"
      '';
    }
  );
}
