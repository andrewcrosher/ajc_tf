#!/usr/bin/env bash
set -euo pipefail

# Log in to Azure in Codespaces using device code flow
if ! command -v az >/dev/null 2>&1; then
	echo "Azure CLI (az) not found. Please rebuild the devcontainer or install az." >&2
	exit 1
fi

az login --use-device-code
echo "Logged in. Current account:"
az account show --output table || true
