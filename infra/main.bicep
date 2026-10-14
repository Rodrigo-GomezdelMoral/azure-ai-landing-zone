targetScope = 'resourceGroup'

import { modelDeployment } from 'modules/foundry.bicep'

@description('Region of every regional resource; defaults to the location of the existing resource group.')
param location string = resourceGroup().location
@description('Environment name recorded in the env tag.')
param environmentName string = 'prod'
@description('Email address that receives budget and alert notifications. Supplied at deploy time, never committed.')
param alertEmailAddress string
@description('SKU of the three model deployments; DataZoneStandard keeps inference in the EU data zone (ADR-004).')
@allowed(['GlobalStandard', 'DataZoneStandard'])
param modelDeploymentSku string = 'GlobalStandard'
@description('Chat model for answering, reranking and agents.')
param chatModel modelDeployment = { name: 'gpt-5-mini', version: '2025-08-07', capacity: 100, guarded: true }
@description('Small chat model for query planning and classification.')
param smallChatModel modelDeployment = { name: 'gpt-5-nano', version: '2025-08-07', capacity: 100, guarded: true }
@description('Embedding model for integrated vectorisation and the workloads.')
param embeddingModel modelDeployment = { name: 'text-embedding-3-small', version: '1', capacity: 120, guarded: false }
@description('Search service pricing tier.')
@allowed(['basic', 'standard'])
param searchSku string = 'basic'
@description('Monthly budget of this resource group in the billing currency of the subscription.')
param budgetAmount int = 80
@description('First day of the month the budget starts; defaults to the current month.')
param budgetStartDate string = utcNow('yyyy-MM-01')

var workload = 'aiplatform'
var regionCode = 'swc'
var tags = { workload: workload, env: environmentName, owner: 'portfolio', managedBy: 'bicep', repo: 'azure-ai-landing-zone' }

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    workspaceName: 'log-${workload}-shared-${regionCode}'
    actionGroupName: 'ag-${workload}-shared'
    alertEmailAddress: alertEmailAddress
    budgetName: 'budget-${workload}-monthly'
    budgetAmount: budgetAmount
    budgetStartDate: budgetStartDate
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    tags: tags
    accountName: 'fdry-${workload}-shared-${regionCode}'
    projectName: 'proj-${workload}-shared'
    modelDeploymentSku: modelDeploymentSku
    deployments: [chatModel, smallChatModel, embeddingModel]
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module search 'modules/search.bicep' = {
  name: 'search'
  params: {
    location: location
    tags: tags
    searchServiceName: 'srch-${workload}-shared-${regionCode}'
    sku: searchSku
    foundryAccountName: foundry.outputs.accountName
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    registryName: 'cr${workload}shared${regionCode}'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

@description('Foundry account endpoint for the Azure OpenAI and Foundry Tools APIs.')
output foundryEndpoint string = foundry.outputs.endpoint
@description('Foundry account name.')
output foundryAccountName string = foundry.outputs.accountName
@description('Foundry account resource id, the scope of model access roles.')
output foundryResourceId string = foundry.outputs.accountId
@description('Foundry project endpoint for agents, evaluations and the Foundry SDK.')
output foundryProjectEndpoint string = foundry.outputs.projectEndpoint
@description('Foundry project name.')
output foundryProjectName string = foundry.outputs.projectName
@description('Deployment name of the chat model.')
output chatDeploymentName string = foundry.outputs.deploymentNames[0]
@description('Deployment name of the small chat model.')
output smallChatDeploymentName string = foundry.outputs.deploymentNames[1]
@description('Deployment name of the embedding model.')
output embeddingDeploymentName string = foundry.outputs.deploymentNames[2]
@description('Search endpoint.')
output searchEndpoint string = search.outputs.searchEndpoint
@description('Search service name.')
output searchServiceName string = search.outputs.searchServiceName
@description('Search service resource id, the scope of Search data-plane roles.')
output searchResourceId string = search.outputs.searchResourceId
@description('Object id of the search identity, for the Storage Blob Data Reader grant each workload declares on its own container.')
output searchPrincipalId string = search.outputs.searchPrincipalId
@description('Registry login server.')
output registryLoginServer string = registry.outputs.registryLoginServer
@description('Registry name.')
output registryName string = registry.outputs.registryName
@description('Log Analytics workspace resource id for Application Insights and diagnostic settings.')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
@description('Action group resource id for workload alerts.')
output actionGroupId string = monitoring.outputs.actionGroupId
@description('Name of this resource group, for modules the workloads scope to it.')
output sharedResourceGroupName string = resourceGroup().name
