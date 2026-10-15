using './main.bicep'

param alertEmailAddress = readEnvironmentVariable('ALERT_EMAIL_ADDRESS')
param modelDeploymentSku = readEnvironmentVariable('MODEL_DEPLOYMENT_SKU', 'GlobalStandard')
param searchLocation = readEnvironmentVariable('SEARCH_LOCATION', 'swedencentral')
param searchRegionCode = readEnvironmentVariable('SEARCH_REGION_CODE', 'swc')
