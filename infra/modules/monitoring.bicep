@description('Azure region of the Log Analytics workspace and the workbook.')
param location string

@description('Name of the shared Log Analytics workspace.')
param workspaceName string

@description('Name of the action group that receives budget and platform alerts.')
param actionGroupName string

@description('Email address the action group notifies, supplied at deployment time.')
param alertEmailAddress string

@description('Tags applied to every resource.')
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2026-03-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: { disableLocalAuth: true }
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: workspace
  name: 'to-log-analytics'
  properties: {
    workspaceId: workspace.id
    logs: [{ category: 'Audit', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'aiplatform'
    enabled: true
    emailReceivers: [{ name: 'platform-owner', emailAddress: alertEmailAddress, useCommonAlertSchema: true }]
  }
}

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'model-usage-by-repo')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'AI platform: model usage and error rate by repo'
    category: 'workbook'
    serializedData: loadTextContent('../../monitoring/workbook.json')
    sourceId: 'Azure Monitor'
  }
}

@description('Resource ID of the shared Log Analytics workspace.')
output workspaceId string = workspace.id

@description('Resource ID of the action group.')
output actionGroupId string = actionGroup.id
