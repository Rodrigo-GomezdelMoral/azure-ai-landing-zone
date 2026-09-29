targetScope = 'subscription'

@description('Workload prefix in every resource name; a second copy of this design needs another value.')
param workload string

@description('Environment recorded in the env tag.')
param env string

@description('Email address that receives budget and platform alerts.')
param alertEmailAddress string

@description('Monthly budget, in the billing currency of the subscription.')
param budgetAmount int

@description('First day of the month the budget starts, as YYYY-MM-DD; Azure rejects changes after creation.')
param budgetStartDate string

var location = 'swedencentral'
var tags = { workload: workload, env: env, owner: 'portfolio', managedBy: 'bicep', repo: 'azure-ai-landing-zone' }
var names = {
  hubRg: 'rg-${workload}-hub-swc'
  sharedRg: 'rg-${workload}-shared-swc'
  vnet: 'vnet-${workload}-hub-swc'
  workspace: 'log-${workload}-shared-swc'
  actionGroup: 'ag-${workload}-shared'
  foundry: 'fdry-${workload}-shared-swc'
  search: 'srch-${workload}-shared-swc'
  registry: 'cr${workload}sharedswc'
}

// IDs are built from names, not module outputs: what-if skips any module whose inputs are another's outputs.
var workspaceId = resourceId(subscription().subscriptionId, names.sharedRg, 'Microsoft.OperationalInsights/workspaces', names.workspace)
var hubVnetId = resourceId(subscription().subscriptionId, names.hubRg, 'Microsoft.Network/virtualNetworks', names.vnet)
var privateLinkSubnetId = '${hubVnetId}/subnets/snet-privatelink'

resource hubRg 'Microsoft.Resources/resourceGroups@2025-04-01' = { name: names.hubRg, location: location, tags: tags }

resource sharedRg 'Microsoft.Resources/resourceGroups@2025-04-01' = { name: names.sharedRg, location: location, tags: tags }

module monitoring 'modules/monitoring.bicep' = {
  scope: sharedRg
  params: {
    location: location
    workspaceName: names.workspace
    actionGroupName: names.actionGroup
    alertEmailAddress: alertEmailAddress
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  scope: hubRg
  params: {
    location: location
    name: names.vnet
    addressPrefix: '10.0.0.0/16'
    privateLinkSubnetPrefix: '10.0.1.0/24'
    workspaceId: workspaceId
    tags: tags
  }
  dependsOn: [monitoring]
}

module dns 'modules/dns.bicep' = {
  scope: hubRg
  params: { hubVnetId: hubVnetId, tags: tags }
  dependsOn: [network]
}

module foundry 'modules/foundry.bicep' = {
  scope: sharedRg
  params: {
    location: location
    name: names.foundry
    workspaceId: workspaceId
    hubResourceGroupName: names.hubRg
    privateLinkSubnetId: privateLinkSubnetId
    tags: tags
  }
  dependsOn: [monitoring, dns]
}

module search 'modules/search.bicep' = {
  scope: sharedRg
  params: {
    location: location
    name: names.search
    foundryAccountName: names.foundry
    workspaceId: workspaceId
    hubResourceGroupName: names.hubRg
    privateLinkSubnetId: privateLinkSubnetId
    tags: tags
  }
  dependsOn: [foundry]
}

module registry 'modules/registry.bicep' = {
  scope: sharedRg
  params: { location: location, name: names.registry, workspaceId: workspaceId, tags: tags }
  dependsOn: [monitoring]
}

module governance 'modules/governance.bicep' = {
  params: {
    budgetName: 'budget-${workload}-monthly'
    budgetAmount: budgetAmount
    budgetStartDate: budgetStartDate
    actionGroupId: resourceId(subscription().subscriptionId, names.sharedRg, 'Microsoft.Insights/actionGroups', names.actionGroup)
  }
  dependsOn: [monitoring]
}

@description('Resource ID of the hub virtual network, the remote end of every spoke peering.')
output hubVnetId string = network.outputs.id
@description('Name of the hub virtual network.')
output hubVnetName string = network.outputs.name
@description('Resource ID of the hub private endpoint subnet.')
output privateLinkSubnetId string = network.outputs.privateLinkSubnetId
@description('Private DNS zone IDs keyed by zone name; spokes link these zones and never create their own.')
output dnsZoneIds object = dns.outputs.zoneIds

@description('Endpoint of the Foundry account.')
output foundryEndpoint string = foundry.outputs.endpoint
@description('Name of the Foundry account.')
output foundryAccountName string = foundry.outputs.name
@description('Resource ID of the Foundry account.')
output foundryResourceId string = foundry.outputs.id
@description('Foundry project endpoints keyed ragplatform and fopcopilot, the target of FoundryChatClient.')
output foundryProjectEndpoints object = foundry.outputs.projectEndpoints
@description('Foundry project resource IDs keyed ragplatform and fopcopilot, the scope of Foundry User grants.')
output foundryProjectResourceIds object = foundry.outputs.projectIds

@description('Endpoint of the AI Search service.')
output searchEndpoint string = search.outputs.endpoint
@description('Name of the AI Search service.')
output searchServiceName string = search.outputs.name
@description('Resource ID of the AI Search service.')
output searchResourceId string = search.outputs.id

@description('Login server of the container registry.')
output registryLoginServer string = registry.outputs.loginServer
@description('Name of the container registry.')
output registryName string = registry.outputs.name

@description('Resource ID of the shared Log Analytics workspace.')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
@description('Resource ID of the platform action group.')
output actionGroupId string = monitoring.outputs.actionGroupId
@description('Name of the shared services resource group.')
output sharedResourceGroupName string = sharedRg.name
@description('Name of the hub network resource group.')
output hubResourceGroupName string = hubRg.name
