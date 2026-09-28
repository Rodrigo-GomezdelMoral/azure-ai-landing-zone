@description('Azure region of the Foundry account and its projects.')
param location string

@description('Name of the Foundry account; also its globally unique custom subdomain.')
param name string

@description('Resource ID of the Log Analytics workspace that receives diagnostics.')
param workspaceId string

@description('Name of the hub resource group that hosts the private endpoint.')
param hubResourceGroupName string

@description('Resource ID of the hub private endpoint subnet.')
param privateLinkSubnetId string

@description('Tags applied to every resource.')
param tags object

var deployments = [
  { model: 'gpt-5-mini', version: '2025-08-07', capacity: 50, guardrail: true }
  { model: 'gpt-5-nano', version: '2025-08-07', capacity: 50, guardrail: true }
  { model: 'text-embedding-3-small', version: '1', capacity: 100, guardrail: false }
]

var projects = {
  ragplatform: 'P01 rag-platform'
  fopcopilot: 'P02 field-operations-copilot'
}

resource account 'Microsoft.CognitiveServices/accounts@2026-07-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    allowProjectManagement: true
    // Lets AI Search call the embedding deployment with its managed identity for integrated vectorisation.
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

resource guardrail 'Microsoft.CognitiveServices/accounts/raiPolicies@2026-07-01' = {
  parent: account
  name: 'guardrail-chat'
  tags: tags
  properties: {
    basePolicyName: 'Microsoft.DefaultV2'
    mode: 'Default'
    contentFilters: concat(
      flatten(map(['Prompt', 'Completion'], source => map(['Hate', 'Sexual', 'Selfharm', 'Violence'], category => {
        name: category
        severityThreshold: 'Medium'
        blocking: true
        enabled: true
        source: source
      }))),
      // Indirect Attack screens retrieved documents and tool output, which RAG and agents feed into prompts.
      map(['Jailbreak', 'Indirect Attack'], shield => { name: shield, blocking: true, enabled: true, source: 'Prompt' }),
      [
        { name: 'Protected Material Text', blocking: true, enabled: true, source: 'Completion' }
        { name: 'Protected Material Code', blocking: false, enabled: true, source: 'Completion' }
      ]
    )
  }
}

// One operation at a time: the account rejects concurrent deployment writes.
@batchSize(1)
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2026-07-01' = [
  for d in deployments: {
    parent: account
    name: d.model
    tags: tags
    sku: { name: 'DataZoneStandard', capacity: d.capacity }
    properties: {
      model: { format: 'OpenAI', name: d.model, version: d.version }
      versionUpgradeOption: 'OnceCurrentVersionExpired'
      raiPolicyName: d.guardrail ? guardrail.name : null
    }
  }
]

resource workloadProjects 'Microsoft.CognitiveServices/accounts/projects@2026-07-01' = [
  for p in items(projects): {
    parent: account
    name: 'proj-${p.key}'
    location: location
    tags: tags
    identity: { type: 'SystemAssigned' }
    properties: { displayName: p.value }
  }
]

resource accountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: account
  name: 'to-log-analytics'
  properties: {
    workspaceId: workspaceId
    logs: map(['Audit', 'RequestResponse', 'Trace'], category => { category: category, enabled: true })
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// Project agent metrics are not exportable through diagnostic settings, so projects send logs only.
resource projectDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [
  for (p, i) in items(projects): {
    scope: workloadProjects[i]
    name: 'to-log-analytics'
    properties: {
      workspaceId: workspaceId
      logs: map(['Audit', 'Trace'], category => { category: category, enabled: true })
    }
  }
]

module privateEndpoint 'private-endpoint.bicep' = {
  scope: resourceGroup(hubResourceGroupName)
  params: {
    name: 'pep-${account.name}'
    location: location
    subnetId: privateLinkSubnetId
    serviceId: account.id
    groupId: 'account'
    dnsZoneNames: ['privatelink.cognitiveservices.azure.com', 'privatelink.openai.azure.com', 'privatelink.services.ai.azure.com']
    tags: tags
  }
  // Project creation succeeds only once the account has converged; binding a private endpoint earlier fails.
  dependsOn: [workloadProjects]
}

@description('Endpoint of the Foundry account.')
output endpoint string = account.properties.endpoint

@description('Name of the Foundry account.')
output name string = account.name

@description('Resource ID of the Foundry account.')
output id string = account.id

@description('Project endpoints keyed by workload, the target of FoundryChatClient.')
output projectEndpoints object = toObject(items(projects), p => p.key, p => 'https://${name}.services.ai.azure.com/api/projects/proj-${p.key}')

@description('Project resource IDs keyed by workload, the scope for Azure AI User grants.')
output projectIds object = toObject(items(projects), p => p.key, p => resourceId('Microsoft.CognitiveServices/accounts/projects', name, 'proj-${p.key}'))
