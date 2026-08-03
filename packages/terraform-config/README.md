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

## Manage

Enter the Terraform development shell. It generates `config.tf.json`, decrypts
the operator credentials into temporary files, exports the authentication
environment variables, and initializes Terraform:

```bash
nix develop .#terraform
```

Use the native Terraform CLI inside the shell:

```bash
terraform plan
terraform apply
```

To build `config.tf.json` without entering the shell:

```bash
nix build .#terraform-config
```
