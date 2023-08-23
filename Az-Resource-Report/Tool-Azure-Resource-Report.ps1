# Report to gather and view compute resource config in Azure.
# Requires AzAccount module.

########## Globally used variables. ##########

############# Public IPs #############
function PublicIPResources {

    # Get Public IP Addresses used.
    $pips = Get-AzPublicIpAddress

    if (($Pips | Measure-Object).Count -ne 0) {

        $publicIPs = foreach ($publicIP in $pips) {

            [PSCustomObject]@{
                Name                 = $publicIP
                Location             = $publicIP.location
                IP_Address           = $publicIP.IpAddress
                IP_Allocation_Method = $publicIP.PublicIpAllocationMethod
                FQDN                 = $publicIP.dnssettings.FQDN
                SKU_Name             = $publicIP.sku.Name
                SKU_Tier             = $publicIP.sku.Tier
            }

        }
        # Format output to console.
        $publicIPs | Format-Table -AutoSize
    }

}

########## Get the VM status. ##########
function azVMResources {

    Write-Host "Getting VM Resources and Status'." -ForegroundColor Yellow
    $vmStatus = Get-AzVM -Status
    Write-Host "VM Information" -ForegroundColor Yellow
    $vmStatus | Select-Object Name,Location,ResourceGroupName,OsName,TimeCreated,PowerState | Sort-Object ResourceGroupName,PowerState,Name | Format-Table -AutoSize
    Start-Sleep 2
    Write-Host "VM States" -ForegroundColor Yellow
    $vmStatus | Group-Object PowerState | Select-Object Name,Count | Format-Table -AutoSize

}

########## Get the VM objects with specific information. ##########
function VMResourceReport {

    # Collect the Az compute resources.
    $AzVMs = Get-AzVM

    # If statement checks the AzVMs variable is not empty before running commands.
    if (($AzVMs | Measure-Object).Count -ne 0 ) {

        # Gets the Azure VM sizes for the VM regions being used.
        $vmLocations = Get-AzVMSize -Location ($AzVMs | Group-Object location).Name
        $vmNICs = Get-AzNetworkInterface
        $vmDisks = Get-AzDisk

        # Loop through VM objects and create a new custom object.
        $vmInfo = foreach ($vm in $AzVMs) {
            Write-Host "Found $($vm.Name)." -ForegroundColor Yellow

            [PSCustomObject]@{
                Name                    = $vm.Name
                PowerState              = (Get-AzVM -Name $vm.Name -Status).PowerState
                Location                = $vm.Location
                VMSize                  = $vm.HardwareProfile.VmSize
                VMSize_CPUCount         = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).NumberOfCores[0]
                VMSize_MemoryGB         = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MemoryInMB[0]
                OS_type                 = $vm.StorageProfile.OsDisk.OsType
                OSDisk_Name             = $vm.StorageProfile.OsDisk.Name
                OSDisk_Size             = ($vmDisks | Where-Object Name -Match $vm.StorageProfile.OsDisk.Name).disksizeGB[-1]
                Attached_Data_Disks     = ($vm.StorageProfile.DataDisks | Measure-Object).Count
                Max_Data_Disk_Supported = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MaxDataDiskCount[0]
                Primary_NIC             = ($vmNICs | Where-Object { ($_.Name -Match $vm.Name) -and ($_.Primary -eq 'True') }).Name
                Private_IP              = (($vmNICs | Where-Object Name -Match $vm.Name).ipconfigurations | Where-Object primary -EQ 'True').PrivateIpAddress
                NICs_Present            = ($vmNICs | Where-Object Name -Match $vm.Name | Measure-Object).Count
            }
        }

        # Format output to console.
        Write-Host "Launching new Window." -ForegroundColor Yellow
        $vmInfo | Out-GridView -Title 'Virtual Machines' -Wait
    }

}

########## Get the NSG objects. ##########
function NSGResources {

    # Get all info on the NSGs.
    $nsgResources = Get-AzNetworkSecurityGroup

    if (($nsgResources | Measure-Object).Count -ne 0 ) {

        # Return the NSG Rules for each NSG.
        $nsgSecurityRules = foreach ($nsg in $nsgResources) {

            # Store the NSG security Rule into the variable $nsgRule.
            $nsgRule = $nsg.SecurityRules

            # Foreach loop goes through the single NSG security Rule and creates a new Hash table.
            foreach ($nsgRuleItem in $nsgRule) {
                [PSCustomObject]@{
                    NSG_Name             = $nsg.Name
                    Priority             = $nsgRuleItem.Priority
                    RuleName             = $nsgRuleItem.Name
                    Direction            = $nsgRuleItem.Direction
                    SourceAddress        = $nsgRuleItem.SourceAddressPrefix -join ','
                    SourcePortRange      = $nsgRuleItem.SourcePortRange -join ','
                    DestionAddress       = $nsgRuleItem.DestinationAddressPrefix -join ','
                    DestinationPortRange = $nsgRuleItem.DestinationPortRange -join ','
                    Description          = $nsgRuleItem.Description
                }
            }
        }
        # Format output to console.
        $nsgSecurityRules | Format-Table * -AutoSize
    }
}

########## Get the vNet objects. ##########
function vNETResources {

    # get vnet config
    $vnetResources = Get-AzVirtualNetwork | Sort-Object Name

    if (($vnetResources | Measure-Object).Count -ne 0 ) {

        # Foerach loop to get the details from the VNet and Subnets within it.
        $VNetDetails = foreach ($vnet in $vnetResources) {

            $vnetSubnetItem = $vnet.Subnets

            foreach ($subnet in $vnetSubnetItem) {
                [PSCustomObject]@{
                    vNetName         = $vnet.Name
                    vNetLocation     = $vnet.Location
                    vNetAddressSpace = $vnet.AddressSpace.AddressPrefixes -join ','
                    SubnetGateway    = ($subnet.NatGateway.id -split ('/'))[8]
                    Routetable       = $subnet.RouteTable
                }
            }
        }
        # Format output to console.
        $VNetDetails | Format-Table -AutoSize
    }
}

########## Get the NatGateway objects. ##########
function natGatewayResources {

    $natgwResources = Get-AzNatGateway

    if (($natgwResources | Measure-Object).Count -ne 0) {

        $natgwResources | Format-Table -a Name, ResourceGuid, ResourceGroupName, Location, Type
    }
}

########## Get the LoadBalancer objects. ##########
function loadBalancerResources {

    $loadBalancers = Get-AzLoadBalancer

    # Export Azure LBs Config to file
    if (($loadBalancers | Measure-Object).Count -ne 0) {

        foreach ($LB in $loadBalancerResources) {

            $loadBalancerRules = $LB.LoadBalancingRules

            foreach ($lbRule in $loadBalancerRules) {
                [PSCustomObject]@{
                    SKU                = $LB.Sku.Name
                    SKUTier            = $LB.Sku.Tier
                    FrontEndName       = $LB.FrontendIpConfigurations.Name
                    FontEndIP          = $LB.FrontendIpConfigurations.PrivateIpAddress
                    BackendPoolName    = $LB.BackendAddressPools.Name
                    #BackendIPs =
                    LBRuleName         = $lbRule.Name
                    LBRuleFrontendPort = $lbRule.FrontendPort
                    LBRuleBackendPort  = $lbRule.BackendPort
                    LBRuleProtocol     = $lbrule.Protocol
                    HealthProbeName    = $LB.Probes.Name
                    HealthProbePort    = $LB.Probes.Port
                }
            }
        }
    }
}

########## Get the VPN objects (Gatways and Connections). ##########
function vpnGatewayResources {

    # Get the names of all resource groups in current context.
    $resourceGroups = (Get-AzResourceGroup).ResourceGroupName
    # Use the ResourceGroup varible above to get the vNet Gatway's if they exist in each RG.
    $vNetGateways = $resourceGroups | ForEach-Object { Get-AzVirtualNetworkGateway -ResourceGroupName $_ }

    if ( ($vNetGateways | Measure-Object).Count -ne 0 ) {

        ########## Get VNET-Gateway Information. ##########
        $vNetGateWayInfo = foreach ($gateway in $vNetGateways) {
            [PSCustomObject]@{
                Name          = $gateway.name
                Location      = $gateway.location
                Type          = $gateway.GatewayType
                VPN_Type      = $gateway.VPNType
                Enable_BGP    = $gateway.enablebgp
                Disable_IPsec = $gateway.DisableIPsecProtection
                Enable_PIP    = $gateway.EnablePrivateIpAddress
                Active_Active = $gateway.ActiveActive
                SKU_Name      = $gateway.sku.Name
                SKU_Tier      = $gateway.sku.Tier
                SKU_Capacity  = $gateway.sku.Capacity
            }
        }
        # Format output to console.
        $vNetGateWayInfo | Format-Table -AutoSize

        ########## Get VNET-Gateway Connections. ##########

        # Get the NetGatewayConnection Names and Resource Groups.
        $vNetGatewayConnectionName = $resourceGroups | ForEach-Object { Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $_ | Select-Object name, ResourceGroupName }
        # Request the full list of properties for each of the named NetGatewayConnections, wihtout this, the connection status and ingress\egress is blank for some reason.
        $vNetGatewayConnectionInfo = $vNetGatewayConnectionName | ForEach-Object { Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $_.ResourceGroupName -Name $_.Name }

        $vpnGatewayConnections = foreach ($vNetgatewayConnection in $vNetGatewayConnectionInfo) {
            [PSCustomObject]@{
                Name                = $vNetGatewayConnection.Name
                Resource_Group      = ($vNetGatewayConnection.id).split('/')[4]
                Location            = $vNetGatewayConnection.Location
                Gateway             = ($vNetGatewayConnection.VirtualNetworkGateway1.id).split('/')[-1]
                Remote              = ($vNetGatewayConnection.LocalNetworkGateway2.id).split('/')[-1]
                Connection_Protocol = $vNetgatewayConnection.ConnectionProtocol
                Connection_Status   = $vNetGatewayConnection.ConnectionStatus
                'Egress(GB)'        = [Math]::round(($vNetGatewayConnection.EgressBytesTransferred) / 1GB, 3)
                'Ingress(GB)'       = [Math]::round(($vNetGatewayConnection.IngressBytesTransferred) / 1GB, 3)
            }
        }
        # Format output to console.
        $vpnGatewayConnections | Sort-Object -Descending 'Egress(GB)', 'Ingress(GB)' | Format-Table -AutoSize
    }
}

########## Get DNS Zones. ##########
function DNSZones {

    # Get the DNS Zones and all properties
    $dnsZones = Get-AzDnsZone

    if ( ($PrivateDNS | Measure-Object).Count -ne 0 ) {

        $dnsZonesOutput = foreach ($dnszone in $dnsZones) {

            [PSCustomObject]@{
                Name              = $dnszone.Name
                Resource_Group    = $dnszone.ResourceGroupName
                Zone_Type         = $dnszone.ZoneType
                Number_of_Records = $dnszone.NumberOfRecordSets
                NameServers       = $dnszone.NameServers -join ","
                Tags              = $dnszone.Tags
            }

        }
        # Format output to console.
        $dnsZonesOutput | Format-Table
    }

}

########## Get Recovery Service Vaults. ##########
function recoveryServiceVaults {

    # Get all the rsvs and their properties.
    $rsvResources = Get-AzRecoveryServicesVault

    if ( ($Vaults | Measure-Object).Count -ne 0 ) {

        $rsvOutput = foreach ($rsv in $rsvResources) {

            # Capture the resv properties using the vaultID.
            $rsvProperties = Get-AzRecoveryServicesVaultProperty -VaultId $rsv.ID

            [PSCustomObject]@{
                Name                            = $rsv.Name
                Location                        = $rsv.Location
                Resource_Group                  = $rsv.ResourceGroupName
                StorageType                     = $rsvProperties.StorageType
                Enhanced_Security               = $rsvProperties.EnhancedSecurityState
                SoftDelete                      = $rsvProperties.SoftDeleteFeatureState
                Encryption_UserID               = $rsvProperties.encryptionProperties.UserAssignedIdentity
                Encryption_SystemID             = $rsvProperties.encryptionProperties.UseSystemAssignedIdentity
                EncryptionAtRestType            = $rsvProperties.encryptionProperties.EncryptionAtRestType
                Infrastructure_Encryption_State = $rsvProperties.encryptionProperties.InfrastructureEncryptionState
            }
        }
        # Format output to console.
        $rsvOutput | Format-Table -AutoSize
    }
}

########## Get Azure Disks. ##########
function azDisks {

    $azDisks = Get-AzDisk

    if ( ($Disks | Measure-Object).Count -ne 0 ) {

        $azDisksOutput = foreach ($disk in $azDisks) {

            [PSCustomObject]@{
                Name               = $disk.Name
                Managed_By         = ($disk.ManagedBy).split("/")[-1]
                RG_Name            = $disk.ResourceGroupName
                Location           = $disk.Location
                TimeCreated        = $disk.TimeCreated
                Size               = $disk.disksizeGB
                State              = $disk.DiskState
                SKU_Name           = $disk.sku.Name
                SKU_Tier           = $disk.sku.Tier
                'Read\Write(IOPS)' = $disk.DiskIOPSReadWrite
                'Read(MBps)'       = $disk.DiskMBpsReadOnly

            }
        }
        # Format output to console.
        $azDisksOutput | Format-Table -AutoSize
    }
}

########## Get Azure Disk Snapshots. ##########
function azDiskSnapshots {
    
    $azSnapShots = Get-AzSnapshot

    if ( ($azSnapShots | Measure-Object).Count -ne 0 ) {

        $azDiskSnapshotsOutput = foreach ($Snap in $azSnapShots) {

            [PSCustomObject]@{
                Name            = $Snap.Name
                RG_Name         = $Snap.ResourceGroupName
                Location        = $Snap.Location
                TimeCreated     = $Snap.TimeCreated
                OSType          = $Snap.OSType
                Source_Object   = ($Snap.CreationData.SourceResourceId).split("/")[-1]
                Creation_Option = $Snap.CreationData.CreateOption
                Incremental     = $Snap.Incremental
                disksizeGB      = $Snap.DiskSizeGB
                AccessPolicy    = $Snap.NetworkAccessPolicy

            }
        }
        # Format output to console.
        Write-Host "This output does not include all fields, only the most useful to see quickly." -ForegroundColor Yellow
        Write-Host 'To see all information, type the command,$azDiskSnapshotsOutput | Format-List.' -ForegroundColor Yellow
        $azDiskSnapshotsOutput | Sort-Object TimeCreated | Format-Table Name,Location,TimeCreated,RG_Name,Source_Object -AutoSize
    }
}

########## Get Azure NICS. ##########
function azNICS {

    $azNICs = Get-AzNetworkInterface

    if ( ($azNICs | Measure-Object).Count -ne 0 ) {
       
        $nicOutput = foreach ($NIC in $azNICs) {
            
            [PSCustomObject]@{
                NIC_Name               = $NIC.Name
                RG                     = $NIC.ResourceGroupName
                Location               = $NIC.Location
                Primary                = $NIC.Primary
                VM_Name                = $NIC.VirtualMachine.id.split('/')[-1]
                MAC_Address            = $NIC.MacAddress
                NSG                    = $NIC.NetworkSecurityGroup
                IP_Forwarding          = $NIC.EnableIPForwarding
                Accelerated_Networking = $NIC.EnableAcceleratedNetworking
                IP_Addresses           = ($NIC.ipconfigurations | ForEach-Object { "$($_.name), $($_.PrivateIpAddress), $($_.PrivateIpAllocationMethod)" -join "," }) -join " / "
            }
        }
        $nicOutput | Format-Table * -AutoSize
    }
    
}

########## Get Azure SQL Resources. ##########
function azSQLResources {
    # Grab all of the sql servers in the current context.
    $azSQLServers = Get-AzSqlServer

    if ( ($azSQLServers | Measure-Object).Count -ne 0 ) {
        # Loop through each SQL server found.
        $sqlResourcesOutput = foreach ($Server in $azSQLServers) {

            # Find all databases under the sql server.
            $databases = $Server | Get-AzSqlDatabase

            # Loop through each Database and collect information into new object.
            foreach ($db in $databases) {

                [PSCustomObject]@{
                    Server_RG           = $Server.ResourceGroupName
                    Server_Name         = $Server.ServerName
                    Server_FQDN         = $Server.FullyQualifiedDomainName
                    Server_Location     = $Server.location
                    Server_PublicAccess = $Server.PublicNetworkAccess
                    Server_SQLAdmin     = $Server.SqlAdministratorLogin
                    DB_Name             = $db.DatabaseName
                    DB_Creation         = $db.CreationDate
                    DB_Sku              = $db.SkuName
                    DB_Redundant        = $db.ZoneRedundant
                    DB_ReadScale        = $db.ReadScale
                    DB_Paused           = $db.PausedDate
                    DB_Resumed          = $db.ResumedDate
                }
            }  
        }
    }    
}

########## Get Azure Recovery Vaults. ##########

function azRecoveryServicesVaults {

    # Get all of the RSVs in the current context.
    $azRecoveryServiceVaults = Get-AzRecoveryServicesVault

    # Check each vault for resources.
    foreach ($Vault in $azRecoveryServiceVaults) {

        # Check for the different resource types in vault.
        $vmBackupItems = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $Vault.ID | Select-Object *, @{l = 'VaultName'; e = { $Vault.name } }
        $sqlBackupItems = Get-AzRecoveryServicesBackupContainer -ContainerType AzureSQL -VaultId $Vault.ID | Select-Object *, @{l = 'VaultName'; e = { $Vault.name } }
        $saBackupItems = Get-AzRecoveryServicesBackupContainer -ContainerType AzureStorage -VaultId $Vault.ID | Select-Object *, @{l = 'VaultName'; e = { $Vault.name } }
                
    }
    if ( ($vmBackupItems | Measure-Object).Count -ne 0 ) {

        $backupVMOutput = foreach ($vm in $vmBackupItems) {

            [PSCustomObject]@{
                Vault          = $vm.VaultName
                Resource_Name  = $vm.FriendlyName
                Resource_Group = $vm.ResourceGroupName
                Status         = $vm.Status
            }
        }
        $backupVMOutput | Format-Table -AutoSize
    }
    if ( ($sqlBackupItems | Measure-Object).Count -ne 0 ) {

        $backupSQLOutput = foreach ($sqlItem in $sqlBackupItems) {

            [PSCustomObject]@{
                Vault          = $sqlItem.VaultName
                Resource_Name  = $sqlItem.FriendlyName
                Resource_Group = $sqlItem.ResourceGroupName
                Status         = $sqlItem.Status
            }
        }
        $backupSQLOutput | Format-Table -AutoSize
    }
    if ( ($saBackupItems | Measure-Object).Count -ne 0 ) {

        $backupSAOutput = foreach ($saItem in $saBackupItems) {

            [PSCustomObject]@{
                Vault          = $saItem.VaultName
                Resource_Name  = $saItem.FriendlyName
                Resource_Group = $saItem.ResourceGroupName
                Status         = $saItem.Status
            }
        }
        $backupSAOutput | Format-Table -AutoSize
    }
}

########## Get Azure Storage Accounts. ##########
function azStorageAccounts {

    $azSAResouces = Get-AzStorageAccount

    if ( ($azSAResouces | Measure-Object).Count -ne 0 ) {

        $saAccountsOutput = foreach ($sa in $azStorageAccounts) {
            
            [PSCustomObject]@{
                SA_Name             = $sa.StorageAccountName
                Resource_Group      = $sa.ResourceGroupName
                Location            = $sa.PrimaryLocation
                Creation_Time       = $sa.Creationtime
                SKU_Name            = $sa.Sku.Name
                Kind                = $sa.Kind
                Access_Tier         = $sa.Accesstier
                Provisionsing_State = $sa.ProvisioningState
                Statusof_Primary    = $sa.StatusOfPrimary
                Statusof_Secondary  = $sa.StatusOfSecondary
                HTTPS_traffic_only  = $sa.EnableHttpsTrafficOnly
                Blob_public_access  = $sa.AllowBlobPublicAccess
                Large_FileShares    = $sa.LargeFileShares
                TLS_Version         = $sa.MinimumTlsVersion
                Tags                = $sa.Tags
            } 
        }
        $saAccountsOutput | Format-Table -AutoSize
    }    
}
