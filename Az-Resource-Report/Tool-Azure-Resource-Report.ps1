# Report to gather and view compute resource config in Azure.
# Requires AzAccount module.

########## Globally used variables. ##########

# $ExportPath = "C:\temp\Az-Compute-Resouces-Report\"
# This variable collects the one datetime to append to all files so they relate to the same report.
# $DateTimeWhilstRunning = (Get-Date).ToString("dd-MM-yy_hh-mm-ss")

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
        $publicIPs | Format-Table -AutoSize
        # Exports the data table from $pipOutputTable to csv to store for later.
    }

}

########## Get the VM objects. ##########
function VMResources {

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

            [PSCustomObject]@{
                Name                    = $vm.Name
                PowerState              = (Get-AzVM -Name $vm.Name -Status).PowerState
                Location                = $vm.Location
                VMSize                  = $vm.HardwareProfile.VmSize
                VMSize_CPUCount         = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).NumberOfCores[0]
                VMSize_MemoryGB         = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MemoryInMB[0]
                OS_type                 = $vm.StorageProfile.OsDisk.OsType
                OSDisk_Name             = $vm.StorageProfile.OsDisk.Name
                OSDisk_Size             = ($vmDisks | Where-Object Name -Match $vm.StorageProfile.OsDisk.Name).disksizeGB
                Attached_Data_Disks     = ($vm.StorageProfile.DataDisks | Measure-Object).Count
                Max_Data_Disk_Supported = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MaxDataDiskCount[0]
                Primary_NIC             = ($vmNICs | Where-Object { ($_.Name -Match $vm.Name) -and ($_.Primary -eq 'True') }).Name
                Private_IP              = (($vmNICs | Where-Object Name -Match $vm.Name).ipconfigurations | Where-Object primary -EQ 'True').PrivateIpAddress
                NICs_Present            = ($vmNICs | Where-Object Name -Match $vm.Name | Measure-Object).Count
            }
        }

        # Export VMs to csv file
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
        $VNetDetails | Format-Table -AutoSize
    }
}

########## Get the vNet objects. ##########
function natGatewayResources {

    $natgwResources = Get-AzNatGateway

    if (($natgwResources | Measure-Object).Count -ne 0) {

        $natgwResources | Format-Table -a Name, ResourceGuid, ResourceGroupName, Location, Type
    }

}

########## Get the vNet objects. ##########
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
        $azDiskSnapshotsOutput | Format-Table * -AutoSize
    }

}