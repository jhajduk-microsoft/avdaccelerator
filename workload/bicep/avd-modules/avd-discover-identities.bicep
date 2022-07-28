
@description('Required. Location where to deploy AVD management plane (Default: eastus2)')
param avdManagementPlaneLocation string

//Discover Tenant AAD Roles before attempting to creat them
/*module DiscoverExistingRoles '../../../carml/1.2.0/Microsoft.Resources/deploymentScripts/deploy.bicep' = {
  scope: resourceGroup('${avdWorkloadSubsId}', '${avdComputeObjectsRgName}')
  name: 'runPowerShellInlineWithOutput'
  params: {
    name: 'discoverExistingRoles'
    location: avdManagementPlaneLocation
    kind: 'AzurePowerShell'
    azPowerShellVersion: '6.4'
    scriptContent: ''' 
    $role = Get-AzRoleDefinition -Name 'StartVMonConnect-AVD'
    if ($role) 
    {
        $roleExists = $true
    } 
    else 
    {
        $roleExists = $false
    }
    $DeploymentScriptsOutputs = @{}
    $DeploymentScriptOutputs['roleExists'] = $roleExists
    '''    
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}*/

resource DiscoverExistingRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'discoverExistingRoles'
  location: avdManagementPlaneLocation
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.4'
    scriptContent: ''' 
    $role = Get-AzRoleDefinition -Name 'StartVMonConnect-AVD'
    if ($role) 
    {
        $roleExists = $true
    } 
    else 
    {
        $roleExists = $false
    }
    $DeploymentScriptsOutputs = @{}
    $DeploymentScriptOutputs['roleExists'] = $roleExists
    '''  
    retentionInterval: 'P1D'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

output scriptOutputs object = DiscoverExistingRoles.properties.outputs
