@export()
@description('A model deployment: name is the model name and becomes the deployment name; capacity is thousands of tokens per minute; guarded applies the chat guardrail.')
type modelDeployment = { name: string, version: string, capacity: int, guarded: bool }

@description('Region of the account, the project and the deployments.')
param location string
@description('Tags applied to every taggable resource.')
param tags object
@description('Account name; also its custom subdomain, which token-based authentication requires.')
param accountName string
@description('Project name. One project is shared by every workload.')
param projectName string
@description('SKU of every model deployment. GlobalStandard routes to any Azure region; DataZoneStandard keeps inference inside the EU data zone.')
@allowed(['GlobalStandard', 'DataZoneStandard'])
param modelDeploymentSku string = 'GlobalStandard'
@description('Model deployments, created one at a time because the account serialises deployment operations.')
param deployments modelDeployment[]
@description('Resource id of the Log Analytics workspace that receives logs and metrics.')
param logAnalyticsWorkspaceId string

var harmCategories = ['Hate', 'Sexual', 'Violence', 'Selfharm']
var harmFilters = flatten(map(['Prompt', 'Completion'], source => map(harmCategories, category => {
  name: category
  severityThreshold: 'Medium'
  blocking: true
  enabled: true
  source: source
})))
var shieldFilters = [
  { name: 'Jailbreak', blocking: true, enabled: true, source: 'Prompt' }
  { name: 'Protected Material Text', blocking: true, enabled: true, source: 'Completion' }
  { name: 'Protected Material Code', blocking: true, enabled: true, source: 'Completion' }
]

resource account 'Microsoft.CognitiveServices/accounts@2026-07-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: accountName
    allowProjectManagement: true
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2026-07-01' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: projectName
    description: 'Shared project for the portfolio workloads: evaluations, traces and model access.'
  }
}

resource guardrail 'Microsoft.CognitiveServices/accounts/raiPolicies@2026-07-01' = {
  parent: account
  name: 'guardrail-chat'
  properties: {
    basePolicyName: 'Microsoft.DefaultV2'
    mode: 'Default'
    contentFilters: concat(harmFilters, shieldFilters)
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2026-07-01' = [for model in deployments: {
  parent: account
  name: model.name
  tags: tags
  sku: { name: modelDeploymentSku, capacity: model.capacity }
  properties: {
    model: { format: 'OpenAI', name: model.name, version: model.version }
    versionUpgradeOption: 'NoAutoUpgrade'
    raiPolicyName: model.guarded ? guardrail.name : null
  }
}]

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-shared-workspace'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

@description('Account name.')
output accountName string = account.name
@description('Account resource id, the scope of role assignments for model access.')
output accountId string = account.id
@description('Account endpoint for the Azure OpenAI and Foundry Tools APIs.')
output endpoint string = account.properties.endpoint
@description('Project name.')
output projectName string = project.name
@description('Project endpoint for agents, evaluations and the Foundry SDK.')
output projectEndpoint string = project.properties.endpoints['AI Foundry API']
@description('Deployment names in the order the deployments parameter listed them.')
output deploymentNames string[] = [for (model, i) in deployments: deployment[i].name]
