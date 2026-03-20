# Key Vault Integration with Azure DevOps Variable Groups

This guide explains how to integrate Azure Key Vault with Azure DevOps to securely manage secrets and configuration.

## Prerequisites

- Azure Key Vault deployed in your subscription (e.g., `eshoponwebkv`)
- Azure DevOps project (e.g., `eShopOnWeb`)
- Permissions to manage variable groups in Azure DevOps
- Azure CLI installed

## Step 1: Create Variable Groups

Run the provided script to create three variable groups linked to your Key Vault:

```bash
export AZDO_ORG_URL=https://dev.azure.com/yourOrg
export AZDO_PROJECT=eShopOnWeb
export AZDO_PAT=your-personal-access-token

# Optional parameters (defaults shown):
# - Vault name: eshoponwebkv
# - Resource group: Eshop-wus-rg
# - Subscription ID: 24e9df87-f699-49ca-ad4e-eaf026d4fbf8

bash scripts/create-azdo-variable-groups.sh [VAULT_NAME] [RESOURCE_GROUP] [SUBSCRIPTION_ID]
```

This creates three variable groups:

1. **Common-Secrets** – Linked to Key Vault; pull secrets dynamically
2. **Build-Config** – Build pipeline variables (DOTNET_VERSION, REGISTRY, etc.)
3. **Deployment-Config** – Deployment pipeline variables (AZURE_SERVICE_CONNECTION, RESOURCE_GROUP, etc.)

## Step 2: Authorize Variable Groups in Azure DevOps UI

1. Go to **Pipelines** → **Library** → **Variable groups**
2. Select **Common-Secrets**
3. Click **Pipeline permissions** and allow it for your pipelines
4. Click **Manage** to add specific secrets from Key Vault:
   - Azure DevOps will fetch them on-demand during pipeline execution
   - Secrets are never logged in pipeline output

## Step 3: Add Secrets to Key Vault

Add secrets via Azure CLI or the Azure Portal:

```bash
az keyvault secret set \
  --vault-name eshoponwebkv \
  --name "sonar-token" \
  --value "your-sonarcloud-token"

az keyvault secret set \
  --vault-name eshoponwebkv \
  --name "registry-password" \
  --value "your-acr-password"

az keyvault secret set \
  --vault-name eshoponwebkv \
  --name "db-connection-string" \
  --value "Server=...;Database=...;User Id=...;Password=..."
```

## Step 4: Reference in Pipeline

Use variable groups in your pipeline YAML:

```yaml
variables:
  - group: Common-Secrets      # Pulls from Key Vault
  - group: Build-Config        # Non-secret build config
  - group: Deployment-Config   # Deployment variables
```

In pipeline steps, reference variables like:

```yaml
- task: SonarCloudPrepare@1
  inputs:
    SonarCloud: 'SonarCloudConnection'
    organization: '$(SONARCLOUD_ORG)'
    projectKey: 'eShopOnWeb'

- task: Docker@2
  inputs:
    containerRegistry: '$(REGISTRY)'
    repository: '$(IMAGE_REPO)'
```

## Step 5: Grant Key Vault Access

Ensure your Azure DevOps service connection has **Get** and **List** permissions on Key Vault secrets:

```bash
SERVICE_PRINCIPAL_ID=$(az keyvault show \
  --name eshoponwebkv \
  --query id \
  --output tsv)

# Grant Get and List on secrets
az role assignment create \
  --assignee <service-principal-id> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<subscription-id>/resourceGroups/Eshop-wus-rg/providers/Microsoft.KeyVault/vaults/eshoponwebkv
```

Or use Azure Portal:
1. Go to **Key Vault** → **Access Policies**
2. Add the service principal (from your service connection)
3. Grant: **Get**, **List** for **Secret permissions**

## Security Best Practices

✅ **Do:**
- Store all sensitive data (API keys, connection strings, passwords) in Key Vault
- Use managed identities instead of service principals when possible
- Enable Key Vault soft delete and purge protection
- Audit Key Vault access logs regularly
- Rotate secrets periodically

❌ **Don't:**
- Store secrets in pipeline YAML or git repo
- Use hardcoded credentials in scripts
- Share variable group access unless necessary
- Log secret values in pipeline output

## Troubleshooting

### "Variable group not authorized for this pipeline"
- Go to **Pipelines** → **Library** → **Variable groups** → **[name]** → **Pipeline permissions**
- Click **+** and select your pipeline

### "Access denied to Key Vault"
- Verify the service connection has **Key Vault Secrets User** role
- Check Key Vault access policies (not just RBAC)
- Ensure firewall rules allow your service connection IP (if configured)

### "Secret not found in Key Vault"
- Verify the secret name exists: `az keyvault secret list --vault-name eshoponwebkv`
- Check the variable group pulls from the correct vault
- Ensure secret name matches exactly (case-sensitive)

## Variable Group Reference

| Group | Type | Usage |
|-------|------|-------|
| **Common-Secrets** | Azure Key Vault | Runtime secrets (tokens, passwords, connection strings) |
| **Build-Config** | Standard | Build configuration (versions, registry names, org names) |
| **Deployment-Config** | Standard | Deployment configuration (subscriptions, resource groups, locations) |

## Example: Using Secrets in CI Pipeline

```yaml
variables:
  - group: Common-Secrets
  - group: Build-Config

stages:
  - stage: Build
    jobs:
      - job: DockerBuild
        steps:
          - task: Docker@2
            displayName: 'Push to ACR'
            inputs:
              command: push
              containerRegistry: '$(REGISTRY)'
              repository: '$(IMAGE_REPO)'
              # REGISTRY password is automatically fetched from Common-Secrets
```

## Example: Using Secrets in CD Pipeline

```yaml
variables:
  - group: Common-Secrets
  - group: Deployment-Config

stages:
  - stage: Deploy
    jobs:
      - job: DeployInfra
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy infrastructure'
            inputs:
              azureSubscription: $(AZURE_SERVICE_CONNECTION)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                # All secrets and vars are available as environment variables
                az deployment group create \
                  --resource-group $(RESOURCE_GROUP) \
                  --template-file infra/main.bicep
```

## Next Steps

1. Run `create-azdo-variable-groups.sh` to set up variable groups
2. Add secrets to your Key Vault
3. Authorize variable groups in Azure DevOps
4. Update CI/CD pipelines to use `variables: - group: [name]`
5. Test a pipeline run and verify secrets are injected correctly

For more info, see:
- [Microsoft: Link secrets from an Azure Key Vault](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml#link-secrets-from-an-azure-key-vault)
- [Azure Key Vault documentation](https://learn.microsoft.com/en-us/azure/key-vault/)
