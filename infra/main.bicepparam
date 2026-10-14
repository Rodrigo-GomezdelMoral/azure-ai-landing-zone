using './main.bicep'

param alertEmailAddress = readEnvironmentVariable('ALERT_EMAIL_ADDRESS')
param modelDeploymentSku = readEnvironmentVariable('MODEL_DEPLOYMENT_SKU', 'GlobalStandard')
