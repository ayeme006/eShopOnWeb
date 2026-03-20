param name string
param location string = resourceGroup().location
param tags object = {}
param principalId string = ''
param principalType string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // Enable RBAC and disable the old Access Policies
    enableRbacAuthorization: true 
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    // Best practice: prevents accidental deletion
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Instead of an inline policy, we create a formal Role Assignment
// This grants the "Key Vault Secrets Officer" role to the principalId
resource secretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, 'KeyVaultSecretsOfficer')
  scope: keyVault
  properties: {
    // This is the ID for 'Key Vault Secrets User'
    // Use the ID for 'Key Vault Secrets Officer'
roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: principalId
    principalType: principalType // Or 'User'
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
