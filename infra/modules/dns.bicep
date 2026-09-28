@description('Resource ID of the hub virtual network that every zone is linked to.')
param hubVnetId string

@description('Tags applied to every resource.')
param tags object

// The hub is the only owner of these zones; spokes add virtual network links, never their own zones.
var zoneNames = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.documents.azure.com'
  'privatelink.vaultcore.azure.net'
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
  'privatelink.postgres.database.azure.com'
  'privatelink.redis.azure.net'
  'privatelink.servicebus.windows.net'
  'privatelink.eventgrid.azure.net'
]

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in zoneNames: {
    name: zone
    location: 'global'
    tags: tags
  }
]

resource hubLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in zoneNames: {
    parent: zones[i]
    name: last(split(hubVnetId, '/'))
    location: 'global'
    tags: tags
    properties: {
      registrationEnabled: false
      virtualNetwork: { id: hubVnetId }
    }
  }
]

@description('Private DNS zone resource IDs keyed by zone name.')
output zoneIds object = toObject(zoneNames, zone => zone, zone => resourceId('Microsoft.Network/privateDnsZones', zone))
