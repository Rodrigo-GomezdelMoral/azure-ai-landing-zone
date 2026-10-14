@description('Region of the registry.')
param location string
@description('Tags applied to every taggable resource.')
param tags object
@description('Registry name, alphanumeric only because the resource type forbids hyphens.')
param registryName string
@description('Resource id of the Log Analytics workspace that receives logs and metrics.')
param logAnalyticsWorkspaceId string

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: registryName
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: false }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-shared-workspace'
  scope: registry
  properties: { workspaceId: logAnalyticsWorkspaceId, logAnalyticsDestinationType: 'Dedicated', logs: [{ categoryGroup: 'allLogs', enabled: true }], metrics: [{ category: 'AllMetrics', enabled: true }] }
}

@description('Registry name.')
output registryName string = registry.name
@description('Registry login server, the image name prefix for every workload.')
output registryLoginServer string = registry.properties.loginServer
