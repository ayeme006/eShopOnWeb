@description('Generate a Suffix based on the Resource Group ID')
param suffix string = uniqueString(resourceGroup().id)

@description('Use the Resource Group Location')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace that receives App Service diagnostics.')
param logAnalyticsWorkspaceId string

@description('Application Insights connection string for application telemetry. Leave empty to skip this app setting.')
param appInsightsConnectionString string = ''

@description('App Service name. Defaults to a deterministic name based on the resource group.')
param appServiceName string = 'app-${suffix}'

@description('Deployment slot used for blue-green releases.')
param stagingSlotName string = 'staging'

@description('Container image tag for the staging slot deployment.')
param stagingImageTag string = 'latest'


var baseAppSettings = [
  {
    name: 'UseOnlyInMemoryDatabase'
    value: 'true'
  }
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Docker'
  }
  {
    name: 'ASPNETCORE_HTTP_PORTS'
    value: '80'
  }
]

var telemetryAppSettings = empty(appInsightsConnectionString)
  ? []
  : [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsightsConnectionString
      }
      {
        name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
        value: '~2'
      }
      {
        name: 'XDT_MicrosoftApplicationInsights_Mode'
        value: 'recommended'
      }
    ]

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: 'cr${suffix}'
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: 'asp-${suffix}'
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  tags: {}
  properties: {
    siteConfig: {
      acrUseManagedIdentityCreds: true
      appSettings: concat(baseAppSettings, telemetryAppSettings)
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/eshoponweb/web:latest'
    }
    serverFarmId: appServicePlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2022-03-01' = {
  name: stagingSlotName
  parent: webApp
  location: location
  properties: {
    siteConfig: {
      acrUseManagedIdentityCreds: true
      appSettings: concat(baseAppSettings, telemetryAppSettings)
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/eshoponweb/web:${stagingImageTag}'
    }
    serverFarmId: appServicePlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${webApp.name}-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output webAppName string = webApp.name
output slotName string = stagingSlot.name
output webAppPrincipalId string = webApp.identity.principalId
output stagingSlotPrincipalId string = stagingSlot.identity.principalId
