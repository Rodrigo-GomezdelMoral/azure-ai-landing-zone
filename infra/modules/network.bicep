@description('Azure region of the hub network.')
param location string

@description('Name of the hub virtual network.')
param name string

@description('Address space of the hub virtual network, in CIDR notation.')
param addressPrefix string

@description('Address range of the private endpoint subnet, in CIDR notation.')
param privateLinkSubnetPrefix string

@description('Resource ID of the Log Analytics workspace that receives platform metrics.')
param workspaceId string

@description('Tags applied to every resource.')
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2025-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    subnets: [
      {
        name: 'snet-privatelink'
        properties: {
          addressPrefix: privateLinkSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vnet
  name: 'to-log-analytics'
  properties: {
    workspaceId: workspaceId
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

@description('Resource ID of the hub virtual network.')
output id string = vnet.id

@description('Name of the hub virtual network.')
output name string = vnet.name

@description('Resource ID of the private endpoint subnet.')
output privateLinkSubnetId string = vnet.properties.subnets[0].id
