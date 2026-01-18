# Azure Terraform in GitHub Codespaces

Opinionated Terraform setup to deploy Azure resources from a GitHub Codespace. The devcontainer installs Azure CLI and Terraform so you can login and deploy immediately.

## What This Deploys
- Resource groups for each service area
- Azure Storage Account (Data Lake Gen2) with container `albums`
- Azure Databricks Workspace and a single-node cluster
- Azure Data Factory
- Azure Key Vault with access for the signed-in user and a secret containing the storage account key

Region defaults to `uksouth`. Names are based on a prefix + environment, e.g. `ajc-prd-datalake-rg`.

## Repo Structure
- `main.tf` – providers and all resources
- `variables.tf` – configurable inputs (`location`, `resource_prefix`, `environment`)
- `outputs.tf` – `tenant_id`, `object_id`
- `.devcontainer/` – Codespaces dev container with Terraform + Azure CLI
- `scripts/azure-login.sh` – helper to login to Azure in Codespaces

## Prerequisites
- GitHub Codespaces enabled
- Azure subscription with permissions to create the above resources

## Quick Start (Codespaces)
1. Open this repo in a Codespace (Code → Codespaces → Create codespace on main).
2. Authenticate to Azure:
	```bash
	./scripts/azure-login.sh
	# or: az login --use-device-code
	az account show      # verify selected subscription
	```
3. Initialize Terraform:
	```bash
	terraform init
	```
4. Plan and apply (environment is required):
	```bash
	terraform plan -var "environment=dev" -out tfplan
	terraform apply tfplan
	```

Databricks workspace and cluster creation can take several minutes.

## Configuration
Inputs in `variables.tf`:
- `location` (string, default: `uksouth`)
- `resource_prefix` (string, default: `ajc`) – must be globally unique for some resources (e.g., Storage Account, Key Vault)
- `environment` (string, required) – must be either `dev` or `prd`

You can pass variables via CLI flags or a local tfvars file (ignored by git):
```bash
terraform plan -var "environment=dev"
# or
echo 'environment = "dev"' > terraform.auto.tfvars
terraform plan
```

## Outputs
After apply, Terraform prints:
- `tenant_id` – Azure AD tenant ID
- `object_id` – Object ID of the signed-in principal

## Cleanup
Destroy everything created by this configuration:
```bash
terraform destroy -var "environment=dev"
```

## State & Security
- Local state is used by default. State files can contain sensitive data – they are ignored by `.gitignore`.
- `.gitignore` excludes: `.terraform/`, `*.tfstate*`, `*.auto.tfvars`, `tfplan`/`*.plan`, and local env files.
- `.terraform.lock.hcl` is intentionally tracked to pin provider versions (no secrets in it).
- For teams/CI, consider a remote backend (e.g., Azure Storage) and a service principal.

## Troubleshooting
- "Please run az login" – run `./scripts/azure-login.sh` and ensure the correct subscription with `az account show`.
- Name already taken – adjust `resource_prefix` and/or `environment` to ensure globally unique names (storage accounts and Key Vaults are global).
- Permission errors – confirm your Azure role has rights to create RGs, Key Vault, Storage, Databricks, and Data Factory in the selected subscription.

## Devcontainer Notes
The Codespaces devcontainer installs Terraform and Azure CLI. If you change `.devcontainer/*`, rebuild the container from the Command Palette (Rebuild Container) to apply updates.

## Repo Hygiene
- CI: This repo runs Terraform formatting and validation on PRs via GitHub Actions (see `.github/workflows/terraform-ci.yml`).
- Pre-commit: Optional local hooks are configured in `.pre-commit-config.yaml`:
	```bash
	pipx install pre-commit  # or: pip install pre-commit
	pre-commit install
	```
	This enforces whitespace hygiene and runs `terraform fmt` and `terraform validate` before commits.
- Line endings: `.gitattributes` normalizes to LF to avoid cross-platform diffs.
# ajc_tf

`ajc_tf` is a Terraform repository that contains the necessary code to create and manage Azure resources for the `ajc_dbt` repository. This repository automates the provisioning of essential Azure services, including:

- Azure Storage Account
- Azure Key Vault
- Azure Databricks Workspace
- Azure Data Factory

Requires the following

- [Terraform](https://www.terraform.io/downloads.html)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- An Azure account with the necessary permissions to create resources.
