targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Resource Group name for the session hosts.')
param avdComputeObjectsRgName string

@description('Optional. AVD workload subscription ID, multiple subscriptions scenario.')
param avdWorkloadSubsId string

@description('Resource Group Name for Azure Files.')
param avdStorageObjectsRgName string

@description('Resource Group Name for Azure Files.')
param avdServiceObjectsRgName string

@description('Storage account files priovate endpoint name.')
param avdWrklStoragePrivateEndpointName string

@description('AVD subnet ID.')
param avdSubnetId string

@description('Required. Location where to deploy compute services.')
param avdSessionHostLocation string

@description('Optional. This property can be used by user in the request to enable or disable the Host Encryption for the virtual machine. This will enable the encryption for all the disks including Resource/Temp disk at host itself. For security reasons, it is recommended to set encryptionAtHost to True. Restrictions: Cannot be enabled if Azure Disk Encryption (guest-VM encryption using bitlocker/DM-Crypt) is enabled on your VMs.')
param encryptionAtHost bool

@description('Session host VM size. (Defualt: Standard_D2s_v3) ')
param avdSessionHostsSize string

@description('OS disk type for session host. (Defualt: Standard_LRS) ')
param avdSessionHostDiskType string

@description('Market Place OS image')
param marketPlaceGalleryWindows object

@description('Set to deploy image from Azure. Compute Gallery')
param useSharedImage bool

@description('Source custom image ID.')
param avdImageTemplataDefinitionId string

@description('Fslogix Managed Identity Resource ID.')
param fslogixManagedIdentityResourceId string

@description('Fslogix file share SMB multichannel.')
param avdFslogixFileShareMultichannel bool

@description('Subnet resource ID for the Azure Files private endpoint.')
param subnetResourceId string

@description('Local administrator username.')
param avdVmLocalUserName string

@description('Required. AD domain name.')
param avdIdentityDomainName string

@description('Required. Keyvault name to get credentials from.')
param avdWrklKvName string

@description('Required. AVD session host domain join credentials.')
param avdDomainJoinUserName string

@description('Optional. OU path to join AVd VMs.')
param avdOuPath string

@description('Application Security Group (ASG) for the session hosts.')
param avdApplicationSecurityGroupResourceId string

@description('Azure Fies storage account name.')
param avdFslogixStorageName string

@description('Azure Files share name.')
param avdFslogixProfileContainerFileShareName string

@description('Azure Files storage account SKU.')
param fslogixStorageSku string

@description('Azure File share quota')
param avdFslogixFileShareQuotaSize int

@description('Use Azure private DNS zones for private endpoints. (Default: false)')
param avdVnetPrivateDnsZone bool

@description('Use Azure private DNS zones for private endpoints. (Default: false)')
param avdVnetPrivateDnsZoneFilesId string

@description('Name for temporary virtual machine. Used to join Azure Files to domain.')
param tempStorageDomainJoinVmName string

@description('Script name for adding storage account to Active Directory.')
param addStorageToDomainScript string

@description('Script arguments for adding the storage account to Active Directory.')
param addStorageToDomainScriptArgs string

@description('URI for the script for adding the storage account to Active Directory.')
param addStorageToDomainScriptUri string

@description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

// =========== //
// Deployments //
// =========== //

// Call on the KV.
resource avdWrklKeyVaultget 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
    name: avdWrklKvName
    scope: resourceGroup('${avdWorkloadSubsId}', '${avdServiceObjectsRgName}')
}

// Provision the storage account and Azure Files.
module fslogixStorage '../../../carml/1.2.0/Microsoft.Storage/storageAccounts/deploy.bicep' = {
    scope: resourceGroup('${avdWorkloadSubsId}', '${avdStorageObjectsRgName}')
    name: 'AVD-Fslogix-Storage-${time}'
    params: {
        name: avdFslogixStorageName
        location: avdSessionHostLocation
        storageAccountSku: fslogixStorageSku
        allowBlobPublicAccess: false
        storageAccountKind: ((fslogixStorageSku =~ 'Premium_LRS') || (fslogixStorageSku =~ 'Premium_ZRS')) ? 'FileStorage' : 'StorageV2'
        storageAccountAccessTier: 'Hot'
        networkAcls: {
            bypass: 'AzureServices'
            defaultAction: 'Deny'
            virtualNetworkRules: []
            ipRules: []
        }
        fileServices: {
            shares: [
                {
                    name: avdFslogixProfileContainerFileShareName
                    shareQuota: avdFslogixFileShareQuotaSize * 100 //Portal UI steps scale
                }
            ]
            protocolSettings: avdFslogixFileShareMultichannel ? {
                smb: {
                    multichannel: {
                        enabled: avdFslogixFileShareMultichannel
                    }
                }
            } : {}
        }
        privateEndpoints: avdVnetPrivateDnsZone ? [
            {
                name: avdWrklStoragePrivateEndpointName
                subnetResourceId: subnetResourceId
                service: 'file'
                privateDnsZoneResourceIds: [
                    avdVnetPrivateDnsZoneFilesId
                ]
            }
        ] : [
            {
                name: avdWrklStoragePrivateEndpointName
                subnetResourceId: subnetResourceId
                service: 'file'
            }
        ]
    }
}

// Provision temporary VM and add it to domain.
module storageVM '../../../carml/1.2.0/Microsoft.Compute/virtualMachines/deploy.bicep' = {
    scope: resourceGroup('${avdWorkloadSubsId}', '${avdStorageObjectsRgName}')
    name: 'Deploy-temporary-VM-FsLogixStorageToDomain-${time}'
    params: {
        name: tempStorageDomainJoinVmName
        location: avdSessionHostLocation
        systemAssignedIdentity: false
        userAssignedIdentities: {
            '${fslogixManagedIdentityResourceId}': {}
        }
        encryptionAtHost: encryptionAtHost
        availabilityZone: []
        osType: 'Windows'
        licenseType: 'Windows_Client'
        vmSize: avdSessionHostsSize
        imageReference: useSharedImage ? json('{\'id\': \'${avdImageTemplataDefinitionId}\'}') : marketPlaceGalleryWindows
        osDisk: {
            createOption: 'fromImage'
            deleteOption: 'Delete'
            diskSizeGB: 128
            managedDisk: {
                storageAccountType: avdSessionHostDiskType
            }
        }
        adminUsername: avdVmLocalUserName
        adminPassword: avdWrklKeyVaultget.getSecret('avdVmLocalUserPassword')
        nicConfigurations: [
            {
                nicSuffix: 'nic-001-'
                deleteOption: 'Delete'
                asgId: !empty(avdApplicationSecurityGroupResourceId) ? avdApplicationSecurityGroupResourceId : null
                enableAcceleratedNetworking: false
                ipConfigurations: [
                    {
                        name: 'ipconfig01'
                        subnetId: avdSubnetId
                    }
                ]
            }
        ]
        // Join domain
        allowExtensionOperations: true
        extensionDomainJoinPassword: avdWrklKeyVaultget.getSecret('avdDomainJoinUserPassword')
        extensionDomainJoinConfig: {
            enabled: true
            settings: {
                name: avdIdentityDomainName
                ouPath: !empty(avdOuPath) ? avdOuPath : null
                user: avdDomainJoinUserName
                restart: 'true'
                options: '3'
            }
        }
    }
    dependsOn: [
        fslogixStorage
    ]
}

// Custom Extension call in on the DSC script to join Azure storage account to domain. 
module addFslogixShareToADDSSript '../../vm-custom-extensions/add-azure-files-to-adds-script.bicep' = {
    scope: resourceGroup('${avdWorkloadSubsId}', '${avdStorageObjectsRgName}')
    name: 'Add-FslogixStorage-to-ADDS-${time}'
    params: {
        location: avdSessionHostLocation
        name: storageVM.outputs.name
        file: addStorageToDomainScript
        ScriptArguments: addStorageToDomainScriptArgs
        baseScriptUri: addStorageToDomainScriptUri
    }
    dependsOn: [
        fslogixStorage
        storageVM
    ]
}

// Run deployment script to remove the VM --> 0.2 release. 
// needs user managed identity --> Virtual machine contributor role assignment. Deployment script to assume the identity to delete VM. Include NIC and disks (force)
