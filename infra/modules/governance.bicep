targetScope = 'subscription'

@description('Name of the monthly cost budget.')
param budgetName string

@description('Monthly budget amount, in the billing currency of the subscription.')
param budgetAmount int

@description('First day of the month the budget starts, as YYYY-MM-DD. Azure rejects changes after creation.')
param budgetStartDate string

@description('Resource ID of the action group notified at each budget threshold.')
param actionGroupId string

// Types whose diagnostic settings carry both logs and metrics: the shared services and the workloads' data stores.
var auditedTypes = [
  'Microsoft.CognitiveServices/accounts'
  'Microsoft.Search/searchServices'
  'Microsoft.ContainerRegistry/registries'
  'Microsoft.OperationalInsights/workspaces'
  'Microsoft.KeyVault/vaults'
  'Microsoft.DocumentDB/databaseAccounts'
  'Microsoft.DBforPostgreSQL/flexibleServers'
  'Microsoft.ServiceBus/namespaces'
  'Microsoft.EventGrid/topics'
  'Microsoft.MachineLearningServices/workspaces'
]

// Built-in definitions, referenced by their public IDs.
var policies = [
  {
    name: 'require-repo-tag'
    definition: '871b6d14-10aa-478d-b590-94f262ecfa99' // Require a tag on resources
    parameters: { tagName: { value: 'repo' } }
    message: 'Tag the resource with repo, the repository that owns it; cost attribution depends on it.'
  }
  {
    name: 'deny-public-blob'
    definition: '4fa4b6c0-31ca-4c0d-b10d-24b96f62a751' // Storage account public access should be disallowed
    parameters: { effect: { value: 'Deny' } }
    message: 'Set allowBlobPublicAccess to false; blobs are reached through private endpoints and identities.'
  }
  {
    name: 'audit-diagnostic-settings'
    definition: '7f89b1eb-583c-429a-8828-af049802c1d9' // Audit diagnostic setting for selected resource types
    parameters: { listOfResourceTypes: { value: auditedTypes } }
    message: 'Send logs and metrics to the shared Log Analytics workspace.'
  }
]

resource assignments 'Microsoft.Authorization/policyAssignments@2026-07-01' = [
  for p in policies: {
    name: p.name
    properties: {
      displayName: p.name
      policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', p.definition)
      parameters: p.parameters
      nonComplianceMessages: [{ message: p.message }]
    }
  }
]

resource budget 'Microsoft.Consumption/budgets@2026-06-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: { startDate: budgetStartDate }
    notifications: toObject([40, 80, 100], pct => 'actual-${pct}-percent', pct => {
      enabled: true
      operator: 'GreaterThanOrEqualTo'
      threshold: pct
      thresholdType: 'Actual'
      contactEmails: []
      contactGroups: [actionGroupId]
    })
  }
}
