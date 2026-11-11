# 🌸 Lumine

Azure VM (Gen 2) running NixOS, being the reverse proxy to almost every self-hosted service.

## LiteLLM

Claude Opus, Sonnet, and Haiku 5.5 share their existing public model names and
aliases across three deployment priorities: Claude OAuth first, the Anthropic
API key second, and Azure Akasha last. Azure is used only when the higher-priority
deployments fail or are unavailable, not for normal load balancing.

Provider HTTP 400 errors, including exhausted credits and invalid parameters,
also permit fallback. This policy applies globally to LiteLLM's model groups.

The container runs rootless under the host's `litellm` account. Podman's
`keep-id` mapping runs the application as container UID/GID `65532:65532` while
preserving host UID/GID `2025:2025`, including Redis socket permissions and
PostgreSQL peer authentication. Application state remains in `/var/lib/litellm`
without an ownership migration. Rootless container storage is persisted
separately in `/var/lib/litellm-podman`. Its user-specific `fuse-overlayfs`
configuration shifts image ownership at mount time, avoiding full-image copy-up
on ZFS when using `keep-id`.

Manage the container through `podman-litellm.service`. To inspect its rootless
Podman storage directly:

```bash
sudo -iu litellm env XDG_RUNTIME_DIR=/run/user/2025 podman ps
```

## Build VHD

To build system disk `.vhd` for uploading, run:

```bash
nix run .#mkimg -- -priv /path/to/host/ssh/privkey --ssh-dir /persist/etc/ssh -f vhd --fixed-size lumine
```

## Upload built VHD to Azure

Start development environment:

```bash
nix develop .#terraform
```

Login to Azure:

```bash
az login --use-device-code
az account set --subscription "d80e6deb-21e3-4aed-9455-5573a2086f66"
```

Upload built vhd to Azure Blob Storage using generated SAS:

```bash
end=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
sas=$(az storage container generate-sas \
    --account-name "constellation" \
    --name "lumine" \
    --expiry $end \
    --permissions acdlrw \
    --auth-mode key | tr -d '"')
azcopy copy ./sda.vhd "https://constellation.blob.core.windows.net/lumine/?$sas" --blob-type PageBlob
```
