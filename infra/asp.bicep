@description('Generate a Suffix based on the Resource Group ID')
param suffix string = uniqueString(resourceGroup().id)

@description('Use the Resource Group Location')
param location string = resourceGroup().location

@description('App Service plan SKU name')
param skuName string = 'S1'

@description('App Service plan tier (e.g. Standard, PremiumV2, PremiumV3)')
param skuTier string = 'Standard'

@description('Initial instance count / capacity for the App Service Plan')
param capacity int = 1

@description('Enable autoscale for the App Service Plan')
param enableAutoscale bool = true

@description('Autoscale minimum instance count')
param autoscaleMin int = 1

@description('Autoscale maximum instance count')
param autoscaleMax int = 3

@description('CPU percentage threshold to scale out (percent)')
param scaleOutCpu int = 70

@description('CPU percentage threshold to scale in (percent)')
param scaleInCpu int = 30

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'asp-${suffix}'
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: skuName
    tier: skuTier
    capacity: capacity
  }
}

resource autoscale 'Microsoft.Insights/autoscaleSettings@2022-10-01' = if (enableAutoscale) {
  name: 'autoscale-asp-${suffix}'
  location: location
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'autoscale-cpu'
        capacity: {
          minimum: string(autoscaleMin)
          maximum: string(autoscaleMax)
          default: string(capacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutCpu
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInCpu
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}
