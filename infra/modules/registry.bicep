@description('Azure region of the container registry.')
param location string

@description('Name of the container registry; alphanumeric only.')
param name string

@description('Resource ID of the Log Analytics workspace that receives diagnostics.')
param workspaceId string

@description('Tags applied to every resource.')
param tags object

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
    // Private link requires Premium (ADR-005); pulls are bound to identities holding AcrPull.
    publicNetworkAccess: 'Enabled'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: registry
  name: 'to-log-analytics'
  properties: {
    workspaceId: workspaceId
    logs: map(['ContainerRegistryRepositoryEvents', 'ContainerRegistryLoginEvents'], category => { category: category, enabled: true })
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

@description('Login server of the registry.')
output loginServer string = registry.properties.loginServer

@description('Name of the registry.')
output name string = registry.name
