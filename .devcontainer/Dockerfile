FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install Terraform and Azure CLI
RUN apt-get update && \
    apt-get install -y curl lsb-release gnupg software-properties-common && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
