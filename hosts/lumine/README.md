# 🌸 Lumine (WIP)

Azure VM (Gen 2) running NixOS, being the reverse proxy to almost every self-hosted service.

## Build VHD

To build system disk `.vhd` for uploading, run:

```bash
nix build .#nixosConfigurations.lumine.config.system.build.azureImage
```

To know the output path of built `.vhd` file, run:

```bash
nix eval .#nixosConfigurations.lumine.config.system.build.azureImage.outPath
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

Generate SAS URI for storage account
```bash
end=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
az storage container generate-sas \
    --account-name "gnosis" \
    --name "lumine" \
    --expiry $end \
    --permissions acdlrw \
    --auth-mode key
```

Upload built vhd to Azure Blob Storage using generated SAS:

```bash
azcopy copy "/path/to/nixos.vhd" "https://gnosis.blob.core.windows.net/lumine/?SAS" --blob-type PageBlob
```
