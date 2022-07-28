@description('Required. Location where to deploy AVD management plane (Default: eastus2)')
param avdManagementPlaneLocation string

@description('Required. Location where to deploy AVD management plane (Default: eastus2)')
param avdWorkloadSubscription string


resource discoverExistingRoles 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'discoverExistingRoles'
  location: avdManagementPlaneLocation
  kind: 'AzurePowerShell'
  properties: {
    arguments: '-subId \'${avdWorkloadSubscription}\''
    azPowerShellVersion: '6.4'
    scriptContent: '''
    param($subId)
    $roleScopeUpdated = $false
    $roleExists = $false
    $role = Get-AzRoleDefinition -Name 'StartVMonConnect-AVD'
    if ($role) {
      $roleExists = $true
      if ($role.IsCustom)
      {
        if ($role.AssignableScopes -inotcontains "/subscriptions/$subid") {
          $newScope = $role.AssignableScopes
          $newScope += "/subscriptions/$subId"
          $strNewScope = $newScope -join ","
          $role.AssignableScopes.Add("/subscriptions/$subId")
          set-AzRoleDefinition -Role $role
          $roleScopeUpdated = $true
          $output = "Role assignable scope updated. New scope: $strNewscope"
        } else {
          $output = "subscription $subId is already included in the role assignable scope"
        }
      } else {
        $output = "The role '$roleName' is not a custom role."
      }
    } else {
      $output = "Cannot find the role definition for '$roleName'."
    }
    Write-Output $output
    $DeploymentScriptsOutputs = @{}
    $DeploymentScriptOutputs['roleExists'] = $roleExists
    $DeploymentScriptOutputs['roleScopeUpdated'] = $roleScopeUpdated
    $DeploymentScriptOutputs['outputText'] = $output
    '''
    retentionInterval: 'P1D'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

output roleExists bool = discoverExistingRoles.properties.outputs.roleExists
