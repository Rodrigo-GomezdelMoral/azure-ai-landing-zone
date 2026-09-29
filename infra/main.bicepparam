using 'main.bicep'

param workload = 'aiplatform'
param env = 'prod'
param alertEmailAddress = readEnvironmentVariable('ALERT_EMAIL_ADDRESS')
param budgetAmount = 300
// The month of the first deployment; Azure rejects any later change to a budget's start date.
param budgetStartDate = '2026-10-01'
