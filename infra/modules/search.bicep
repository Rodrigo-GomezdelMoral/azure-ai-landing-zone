@description('Region of the search service.')
param location string
@description('Tags applied to every taggable resource.')
param tags object
@description('Search service name.')
param searchServiceName string
@description('Pricing tier. The free tier is excluded because it has no managed identity, which the keyless indexer requires.')
@allowed(['basic', 'standard'])
param sku string = 'basic'
@description('Semantic ranker plan: free covers 1,000 requests a month, standard is billed per thousand requests.')
@allowed(['disabled', 'free', 'standard'])
param semanticSearch string = 'standard'
@description('Foundry account the search identity calls for embeddings and for billing built-in skills.')
param foundryAccountName string
@description('Resource id of the Log Analytics workspace that receives logs and metrics.')
param logAnalyticsWorkspaceId string

var cognitiveServicesOpenAiUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var cognitiveServicesUser = 'a97b65f3-24c7-4388-baec-2e87135dc908'

resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: { name: sku }
  identity: { type: 'SystemAssigned' }
  properties: {
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    hostingMode: 'Default'
    replicaCount: 1
    partitionCount: 1
    semanticSearch: semanticSearch
  }
}

module embeddingAccess 'role-assignment.bicep' = {
  name: 'search-embedding-access'
  params: { foundryAccountName: foundryAccountName, principalId: search.identity.principalId, roleDefinitionId: cognitiveServicesOpenAiUser }
}

module skillBillingAccess 'role-assignment.bicep' = {
  name: 'search-skill-billing-access'
  params: { foundryAccountName: foundryAccountName, principalId: search.identity.principalId, roleDefinitionId: cognitiveServicesUser }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-shared-workspace'
  scope: search
  properties: { workspaceId: logAnalyticsWorkspaceId, logs: [{ categoryGroup: 'allLogs', enabled: true }], metrics: [{ category: 'AllMetrics', enabled: true }] }
}

@description('Search service name.')
output searchServiceName string = search.name
@description('Search service resource id, the scope of data-plane role assignments.')
output searchResourceId string = search.id
@description('Search endpoint.')
output searchEndpoint string = 'https://${search.name}.search.windows.net'
@description('Object id of the search identity; workloads grant it read access to their own storage.')
output searchPrincipalId string = search.identity.principalId
