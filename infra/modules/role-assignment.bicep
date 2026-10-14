@description('Name of the Foundry account in this resource group that the role is granted on.')
param foundryAccountName string

@description('Object id of the principal that receives the role.')
param principalId string

@description('Principal type, stated explicitly so the assignment succeeds before a new identity has replicated.')
@allowed(['ServicePrincipal', 'User', 'Group'])
param principalType string = 'ServicePrincipal'

@description('Built-in role definition id, without the subscription prefix.')
param roleDefinitionId string

resource foundry 'Microsoft.CognitiveServices/accounts@2026-07-01' existing = {
  name: foundryAccountName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, principalId, roleDefinitionId)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

@description('Resource id of the role assignment.')
output roleAssignmentId string = assignment.id
