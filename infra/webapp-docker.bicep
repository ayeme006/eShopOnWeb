@description('Generate a Suffix based on the Resource Group ID')
param suffix string = uniqueString(resourceGroup().id)

@description('Use the Resource Group Location')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace that receives App Service diagnostics.')
param logAnalyticsWorkspaceId string

@description('Application Insights connection string for application telemetry. Leave empty to skip this app setting.')
param appInsightsConnectionString string = ''

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

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp-${suffix}'
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${suffix}'
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
