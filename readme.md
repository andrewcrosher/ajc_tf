# Azure Terraform in GitHub Codespaces

Opinionated Terraform setup to deploy Azure resources from a GitHub Codespace. The devcontainer installs Azure CLI and Terraform so you can login and deploy immediately.

## What This Deploys
- Resource groups for each service area (with consistent tagging)
- Azure Storage Account (Data Lake Gen2) with:
  - Container `albums`
  - LRS replication for cost efficiency
  - Blob versioning enabled for data protection
  - Aggressive lifecycle management (cool at 7d, archive at 30d) for minimal storage costs
- Azure Databricks Workspace:
  - Standard SKU (cost-optimized for personal projects)
  - Single-node cluster with smallest available node type
  - Spot instances for maximum cost savings (up to 80% vs on-demand)
  - Auto-termination after 15 minutes of inactivity
- Azure Data Factory:
  - System-assigned managed identity for secure authentication
  - Public network access enabled for operational flexibility
- Azure Key Vault:
  - Standard SKU with 7-day soft delete retention
  - Purge protection disabled for easy cleanup
  - Compact naming pattern to stay within 24-character limit
  - Stores storage account access key

Region defaults to `uksouth`. Names are based on a prefix + environment, e.g. `ajc-prod-datalake-rg`.

## Repo Structure
- `main.tf` – providers and all resources
- `variables.tf` – configurable inputs (`location`, `resource_prefix`, `environment`, `additional_tags`)
- `outputs.tf` – resource identifiers and URIs
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
- `location` (string, default: `uksouth`) – Azure region for resources
- `resource_prefix` (string, default: `ajc`) – must be globally unique and ≤10 characters to satisfy Azure Storage Account naming (`${resource_prefix}${environment}datalakesa` must be ≤24 chars; this also keeps Key Vault names within the 24-character limit)
- `environment` (string, required) – must be either `dev` or `prod`
- `additional_tags` (map, optional) – additional tags to apply to all resources

### Cost Optimization

This configuration is optimized for **minimal costs** suitable for personal projects:

- **Storage**: LRS replication only (lowest cost tier)
- **Storage Lifecycle**: Aggressive tiering (cool at 7 days, archive at 30 days) minimizes storage costs
- **Databricks Workspace**: Standard SKU (not Premium) to avoid premium feature costs
- **Databricks Cluster**: 
  - Spot instances with fallback for up to 80% savings vs on-demand*
  - Smallest available node type
  - 15-minute auto-termination to minimize idle costs
- **Key Vault**: Standard SKU with minimal 7-day retention, no purge protection

*Actual spot instance savings vary based on Azure market conditions. Setting `spot_bid_max_price = -1` allows Azure to charge up to on-demand rates, maximizing availability while typically providing significant cost savings.

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
- `storage_account_name` – Name of the data lake storage account
- `storage_account_id` – Resource ID of the data lake storage account
- `databricks_workspace_url` – URL of the Databricks workspace
- `databricks_workspace_id` – Resource ID of the Databricks workspace
- `data_factory_id` – Resource ID of the Data Factory
- `data_factory_identity_principal_id` – Principal ID of the Data Factory managed identity
- `key_vault_uri` – URI of the Key Vault
- `key_vault_id` – Resource ID of the Key Vault

## Cleanup
Destroy everything created by this configuration:
```bash
terraform destroy -var "environment=dev"
```

**Note**: Purge protection is disabled and soft delete retention is minimal (7 days) for easy cleanup and cost savings. After running `terraform destroy`, resources can be fully removed without manual intervention.

## Cost Optimization Features

This configuration is designed for **minimal costs** on personal projects:

1. **Lowest-Cost SKUs**: Standard tier for all services (no premium features)
2. **Storage Lifecycle Management**: Aggressive tiering (7/30 days for cool/archive) minimizes storage costs
3. **Spot Instances**: All Databricks clusters use spot instances with fallback (actual savings vary with market conditions)
4. **Auto-Termination**: Clusters terminate after 15 minutes of inactivity to eliminate idle costs
5. **LRS Replication**: Locally-redundant storage for lowest storage costs
6. **Minimal Retention**: 7-day soft delete retention to avoid extended storage costs
7. **Resource Tagging**: Comprehensive tags enable cost tracking and analysis

## State & Security
- Local state is used by default. State files can contain sensitive data – they are ignored by `.gitignore`.
- `.gitignore` excludes: `.terraform/`, `*.tfstate*`, `*.auto.tfvars`, Terraform plan files (for example, files named `tfplan` or with `.tfplan`/`.plan` in the name), and local env files.
- `.terraform.lock.hcl` is intentionally tracked to pin provider versions (no secrets in it).
- For teams/CI, consider a remote backend (e.g., Azure Storage) and a service principal.

## Security Features

This configuration implements security best practices while maintaining cost efficiency:

1. **Data Factory Managed Identity**: System-assigned identity eliminates need for stored credentials
2. **Key Vault Protection**: 
   - 7-day soft delete retention for recovery from accidental deletion
   - Purge protection disabled for easy cleanup and redeployment
   - Provider configured to not auto-purge on destroy
3. **Storage Protection**: 
   - Blob versioning enabled for data recovery
   - Environment-specific lifecycle policies manage data retention
4. **Resource Tagging**: All resources tagged for governance and compliance tracking

## Troubleshooting
- "Please run az login" – run `./scripts/azure-login.sh` and ensure the correct subscription with `az account show`.
- Name already taken – adjust `resource_prefix` and/or `environment` to ensure globally unique names (storage accounts and Key Vaults are global).
- Permission errors – confirm your Azure role has rights to create RGs, Key Vault, Storage, Databricks, and Data Factory in the selected subscription.

## Devcontainer Notes
The Codespaces devcontainer installs Terraform and Azure CLI. If you change `.devcontainer/*`, rebuild the container from the Command Palette (Rebuild Container) to apply updates.

## Repo Hygiene
- CI: This repo runs Terraform formatting, validation, linting (TFLint), and secret scanning on PRs via GitHub Actions (see `.github/workflows/terraform-ci.yml` and `.github/workflows/secrets-scan.yml`).
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
