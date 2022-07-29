$avdVmLocalUserPassword = Read-Host -Prompt "Local user password" -AsSecureString
$avdDomainJoinUserPassword = Read-Host -Prompt "Domain join password" -AsSecureString
New-AzSubscriptionDeployment `
  -TemplateFile workload/bicep/deploy-baseline.bicep `
  -TemplateParameterFile workload/bicep/parameters/deploy-baseline-parameters-example.json `
  -avdWorkloadSubsId 9637c0d0-d0a9-4742-bf58-26173af8ab39 `
  -deploymentPrefix avd `
  -avdVmLocalUserName jhajduk `
  -avdVmLocalUserPassword Password1 `
  -avdIdentityDomainName o365test.com `
  -avdDomainJoinUserPassword *jEnnY_B3nnY* `
  -avdDomainJoinUserName jhajduk  `
  -existingHubVnetResourceId /subscriptions/9637c0d0-d0a9-4742-bf58-26173af8ab39/resourceGroups/dc-resource-group/providers/Microsoft.Network/virtualNetworks/ad-vnet  `
  -customDnsIps 10.0.0.4  `
  -avdEnterpriseAppObjectId 9cdead84-a844-4324-93f2-b2e6bb768d07 `
  -Location westus2
