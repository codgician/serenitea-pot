# 🌸 Lumine

Azure VM (Gen 2) running NixOS, being the reverse proxy to almost every self-hosted service.

This virtual machine has impermenance enabled, and has os and data on separate disks.

## Build VHD

To build system disk `.vhd` for uploading, run:

```bash
nix run .#mkimg -- -priv /path/to/host/ssh/privkey --ssh-dir /nix/persist/etc/ssh -f vhd --fixed-size lumine
```

## Upload built VHD to Azure

Start development environment:

```bash
nix develop .#cloud -c $SHELL
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
