@description('Region for the workspace. The action group is a global resource and ignores it.')
param location string

@description('Tags applied to every taggable resource.')
param tags object

@description('Log Analytics workspace name.')
param workspaceName string

@description('Log retention in days. Thirty-one days or fewer are included in the ingestion price.')
param retentionInDays int = 30

@description('Action group name.')
param actionGroupName string

@description('Email address that receives budget and alert notifications. Supplied at deploy time, never committed.')
param alertEmailAddress string

@description('Consumption budget name.')
param budgetName string

@description('Monthly budget amount in the billing currency of the subscription.')
param budgetAmount int

@description('First day of the month the budget starts, as yyyy-MM-dd.')
param budgetStartDate string

@description('Percentages of the budget at which a notification is sent to the action group.')
param budgetThresholds int[] = [40, 80, 100]

resource workspace 'Microsoft.OperationalInsights/workspaces@2026-03-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionInDays
    features: { disableLocalAuth: true }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'aiplatform'
    enabled: true
    emailReceivers: [
      {
        name: 'platform-owner'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

resource budget 'Microsoft.Consumption/budgets@2026-06-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: { startDate: budgetStartDate }
    notifications: toObject(budgetThresholds, threshold => 'actual-${threshold}-percent', threshold => {
      enabled: true
      operator: 'GreaterThanOrEqualTo'
      threshold: threshold
      thresholdType: 'Actual'
      contactEmails: []
      contactGroups: [actionGroup.id]
    })
  }
}

@description('Resource id of the Log Analytics workspace, the destination of every diagnostic setting.')
output workspaceId string = workspace.id

@description('Resource id of the action group that receives budget and alert notifications.')
output actionGroupId string = actionGroup.id
