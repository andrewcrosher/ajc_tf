# Azure Terraform in GitHub Codespaces

Opinionated Terraform setup to deploy Azure resources from a GitHub Codespace. The devcontainer installs Azure CLI and Terraform so you can login and deploy immediately.

## What This Deploys
- Resource groups for each service area (with consistent tagging)
- Azure Storage Account (Data Lake Gen2) with:
  - Container `albums`
  - Environment-based replication (ZRS for prod, LRS for dev)
  - Blob versioning enabled for data protection
  - Environment-specific lifecycle management (prod: cool at 30d/archive at 90d, dev: cool at 7d/archive at 30d)
- Azure Databricks Workspace:
  - Premium SKU for production, Standard for development
  - Single-node cluster with environment-specific configurations
  - Spot instances for dev (cost savings), on-demand for prod
  - Auto-termination (15 min for dev, 30 min for prod)
- Azure Data Factory:
  - System-assigned managed identity for secure authentication
  - Public network access enabled for operational flexibility
- Azure Key Vault:
  - Environment-based purge protection (enabled for prod)
  - Soft delete retention (90 days for prod, 7 days for dev)
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
- `resource_prefix` (string, default: `ajc`) – must be globally unique and ≤18 characters for Key Vault naming (prefix + environment + 'kv' must be ≤24 chars)
- `environment` (string, required) – must be either `dev` or `prod`
- `additional_tags` (map, optional) – additional tags to apply to all resources

### Environment-Specific Configurations

The infrastructure automatically adjusts based on the environment:

**Production (`prod`):**
- Storage: ZRS replication for higher durability
- Storage Lifecycle: Cool tier at 30 days, archive at 90 days
- Databricks: Premium SKU with advanced features
- Databricks Cluster: On-demand instances, 30-minute auto-termination
- Data Factory: Public network access enabled for connectivity
- Key Vault: Purge protection enabled, 90-day soft delete retention

**Development (`dev`):**
- Storage: LRS replication for cost savings
- Storage Lifecycle: Aggressive tiering - cool at 7 days, archive at 30 days
- Databricks: Standard SKU
- Databricks Cluster: Spot instances with fallback (up to 80% cost savings*), 15-minute auto-termination
- Data Factory: Public network access enabled
- Key Vault: Purge protection disabled, 7-day soft delete retention

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

**Note for Production**: Production Key Vaults have purge protection enabled, which prevents immediate deletion. After running `terraform destroy`, you may need to manually purge the Key Vault or wait for the retention period to expire before redeploying.

## Cost Optimization Features

This configuration includes several cost optimization features:

1. **Environment-Based SKUs**: Production uses higher-tier SKUs for reliability, while development uses cost-effective options
2. **Storage Lifecycle Management**: Environment-specific tiering policies (prod: 30/90 days, dev: 7/30 days for cool/archive)
3. **Spot Instances**: Development Databricks clusters use spot instances with fallback (actual savings vary with market conditions)
4. **Auto-Termination**: Clusters automatically terminate after inactivity (15 min dev, 30 min prod)
5. **Replication Strategy**: LRS for dev, ZRS for prod balances cost and durability
6. **Resource Tagging**: Comprehensive tags enable cost tracking and analysis by environment and cost center

## State & Security
- Local state is used by default. State files can contain sensitive data – they are ignored by `.gitignore`.
- `.gitignore` excludes: `.terraform/`, `*.tfstate*`, `*.auto.tfvars`, Terraform plan files (for example, files named `tfplan` or with `.tfplan`/`.plan` in the name), and local env files.
- `.terraform.lock.hcl` is intentionally tracked to pin provider versions (no secrets in it).
- For teams/CI, consider a remote backend (e.g., Azure Storage) and a service principal.

## Security Features

This configuration implements several security best practices:

1. **Data Factory Managed Identity**: System-assigned identity eliminates need for stored credentials
2. **Key Vault Protection**: 
   - Purge protection enabled in production to prevent accidental deletion
   - Extended soft delete retention (90 days) for production
   - Provider configured to not auto-purge on destroy (compatible with purge protection)
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
