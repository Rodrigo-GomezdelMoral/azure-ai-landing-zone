@description('Azure region of the search service; must match the Foundry account for enrichment billing.')
param location string

@description('Name of the AI Search service.')
param name string

@description('Name of the Foundry account in the same resource group that Search calls and bills to.')
param foundryAccountName string

@description('Resource ID of the Log Analytics workspace that receives diagnostics.')
param workspaceId string

@description('Name of the hub resource group that hosts the private endpoint.')
param hubResourceGroupName string

@description('Resource ID of the hub private endpoint subnet.')
param privateLinkSubnetId string

@description('Tags applied to every resource.')
param tags object

// Built-in role IDs rather than names: Microsoft advises IDs while these role families are renamed.
var foundryRoles = {
  vectorisation: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
  enrichmentBilling: 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
}

resource foundry 'Microsoft.CognitiveServices/accounts@2026-07-01' existing = {
  name: foundryAccountName
}

resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'basic' }
  identity: { type: 'SystemAssigned' }
  properties: {
    replicaCount: 1
    partitionCount: 1
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
  }
}

resource foundryGrants 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in items(foundryRoles): {
    scope: foundry
    name: guid(foundry.id, search.id, role.value)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.value)
      principalId: search.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Keyless enrichment billing needs a private path once Foundry's public access is disabled; approve it on Foundry.
resource billingLink 'Microsoft.Search/searchServices/sharedPrivateLinkResources@2025-05-01' = {
  parent: search
  name: 'foundry-billing'
  properties: {
    privateLinkResourceId: foundry.id
    groupId: 'cognitiveservices_account'
    requestMessage: 'Enrichment billing for ${name}'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: search
  name: 'to-log-analytics'
  properties: {
    workspaceId: workspaceId
    logs: [{ category: 'OperationLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

module privateEndpoint 'private-endpoint.bicep' = {
  scope: resourceGroup(hubResourceGroupName)
  params: {
    name: 'pep-${search.name}'
    location: location
    subnetId: privateLinkSubnetId
    serviceId: search.id
    groupId: 'searchService'
    dnsZoneNames: ['privatelink.search.windows.net']
    tags: tags
  }
}

@description('Endpoint of the search service.')
output endpoint string = search.properties.endpoint

@description('Name of the search service.')
output name string = search.name

@description('Resource ID of the search service.')
output id string = search.id
