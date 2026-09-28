@description('Name of the private endpoint; its network interface is named nic-<name>.')
param name string

@description('Azure region of the private endpoint.')
param location string

@description('Resource ID of the subnet that hosts the private endpoint.')
param subnetId string

@description('Resource ID of the service the private endpoint connects to.')
param serviceId string

@description('Private link sub-resource of the target service, such as account or searchService.')
param groupId string

@description('Resource IDs of the private DNS zones that receive the endpoint records.')
param dnsZoneIds string[]

@description('Tags applied to every resource, including the network interface Azure creates.')
param tags object

resource endpoint 'Microsoft.Network/privateEndpoints@2025-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    customNetworkInterfaceName: 'nic-${name}'
    privateLinkServiceConnections: [
      {
        name: name
        properties: { privateLinkServiceId: serviceId, groupIds: [groupId] }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-09-01' = {
  parent: endpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for zoneId in dnsZoneIds: { name: last(split(zoneId, '/')), properties: { privateDnsZoneId: zoneId } }]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2025-09-01' existing = {
  name: 'nic-${name}'
}

// The network resource provider creates this NIC without tags; the tags resource closes that gap.
resource nicTags 'Microsoft.Resources/tags@2025-04-01' = {
  scope: nic
  name: 'default'
  properties: { tags: tags }
  dependsOn: [endpoint]
}
