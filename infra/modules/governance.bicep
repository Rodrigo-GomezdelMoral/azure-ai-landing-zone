targetScope = 'subscription'

@description('Name of the monthly cost budget.')
param budgetName string

@description('Monthly budget amount, in the billing currency of the subscription.')
param budgetAmount int

@description('First day of the month the budget starts, as YYYY-MM-DD. Azure rejects changes after creation.')
param budgetStartDate string

@description('Resource ID of the action group notified at each budget threshold.')
param actionGroupId string

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
