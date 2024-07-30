# 🌩️ Terraform configurations

## Preparations

Create a service principal for Terraform authentication.

```bash
az ad sp create-for-rbac --name 'Terraform' --role Contributor --scopes /subscriptions/d80e6deb-21e3-4aed-9455-5573a2086f66
```

Create a azure storage account for storing terraform states. 

## Apply

To build configuration `.tf.json`:

```bash
nix build .#terraformConfiguration
```

To build and apply configuration:

```bash
nix run .#tfmgr -- apply
```
