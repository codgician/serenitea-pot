# 🌩️ Terraform configurations

This folder contain terraform configurations to set up my infrastructure.

## Preparations

### Celestia (Azure)

Create a service principal for Terraform authentication, here I name it as `caribert`.

```bash
az ad sp create-for-rbac --name 'caribert' --role Contributor --scopes /subscriptions/d80e6deb-21e3-4aed-9455-5573a2086f66
```

Create a azure storage account for storing terraform states.

### Tonatiuh (GCP)

Create a service account (I named it `ochkanatlan`) and assign it as owner role. Create a JSON service account key and use it as authentication credential.

## Apply

To build configuration `.tf.json`:

```bash
nix build .#terraform-config
```

To build and apply configuration:

```bash
nix run .#tfmgr -- apply
```

To get other supported commands, try:

```bash
nix run .#tfmgr -- --help
```
