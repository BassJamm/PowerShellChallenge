<#
    Gets information about the Azure Resources hosted for a tenant.
#>

param(
    [switch]$ExportAllSubscriptions = $False,
    $ExportPath = $null
)

# Gets the date\time for the various output reports.
$DateTimeWhilstRunning = (Get-Date).ToString("dd-MM-yy_hh-mm-ss")

<# ----- Create the Export Directory. ----- #>
if (!$ExportPath) {
    $ExportPath = "S:\Azure\Azure\ConfigExports\$(get-date -UFormat '%d-%m-%Y')\$((Get-AzContext).Subscription.Name)\Tenant-Config-$($DateTimeWhilstRunning)"
}
# Create the directory if not already exists
if (Test-Path -PathType Container -Path $ExportPath) {
    Verbose-Msg -Action "Skipped" -Section "Export Directory already present." -Result "No directory created."
} else {
    Verbose-Msg -Action "Action" -Section "Export Directory Being Created" -Result "$ExportPath"
    New-Item -Path $ExportPath -Force -ErrorAction Continue -ItemType Directory
}

# Function to export the resources.
Function ExportTenantConfig() {
    

    # Start banner.
    Verbose-Msg -action "Starting" -Section "Query and Export of Subscription" -Result "**** $((Get-AzContext).Subscription.Name) ****"

    <# ----- ########## Azure Contenxt ########## ----- #>

    Verbose-Msg -action "Querying" -Section "Azure Context" -Result "Starting"

    $AzContext = Get-AzContext
    $AzContext | Export-Clixml $ExportPath\Config-Context.clixml

    $azContextAttributes = @(
        @{l='SubscriptionName';e={$_.Subscription.Name}},
        @{l='TenantId';e={$_.Tenant.Tenantid}},
        'Subscription',
        'Environment',
        @{l='QueryAzureAccount';e={$_.Account}},
        @{l='QueryHostDetails';e={"User: $($env:USERDOMAIN)\$($env:username) on Computer: $($Env:computername)"}},
        @{l='QueryDateTime';e={Get-Date -Format "yyyy-MM-dd HH:mm" }}
    )
    $AzContext | Select-Object $azContextAttributes | Export-Csv -NoTypeInformation $ExportPath\Details-Context.csv

    Verbose-Msg -action "Exported" -Section "Azure Context" -Result "Completed"

    <# ----- ########## Public IPs ########## ----- #>

    #Verbose-Msg "Querying: Public IPs"
    Verbose-Msg -Action "Querying" -Section "Public IPs" -Result "Starting"

    # Get Public IP Addresses used.
    $pips = Get-AzPublicIpAddress

    if (($Pips | Measure-Object).Count -ne 0){
    
        # Export PublicIP Config to file.
        $pips | Export-Clixml $ExportPath\Config-PublicIPs.clixml

        # Array for the attributes to select from variable $pips.
        $pipAttributes = @(
            'Name',
            'Location',
            'IPAddress',
            'PublicIpAllocationMethod',
            @{l='SKU-Name';e={"$($_.Sku.name)"}},
            @{l='SKU-Tier';e={"$($_.sku.Tier)"}},
            @{l='FQDN';e={$_.dnssettings.fqdn}}
        )
        # Select the attributes from $pips using the array above.
        $pipOutputTable = $pips | Select-Object $pipAttributes

        # Exports the data table from $pipOutputTable to csv to store for later.
        $pipOutputTable | Export-Csv $ExportPath\Details-PublicIPs.csv -NoTypeInformation

        Verbose-Msg -Action "Exported" -Section "Public IPs" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Public IPs" -Result "None"
    }

    ############# VMs   ########################################################

    #Verbose-Msg "Querying: VMs"
    Verbose-Msg -Action "Querying" -Section "VMs" -Result "Starting"

    #Pre-req: $Pips variable with public ips in it from earlier query.
   
    $AzVMs = Get-AzVM                                                               # Get VM list

    if (($AzVMs | Measure-Object).Count -ne 0 ) { 
        # Export VMs to clixml file

        $vmLocations = Get-AzVMSize -Location ($AzVMs | Group-Object location).Name # Get VM sizes in that location.
        $vmNICs = Get-AzNetworkInterface                                            # Get the NICS in Subscription.

        $vmInfo = foreach ($vm in $AzVMs) {

            [PSCustomObject]@{
                Name = $vm.Name
                Location = $vm.Location
                Size = $vm.HardwareProfile.VmSize
                CPUCount = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).NumberOfCores[0]
                MemoryGB = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MemoryInMB[0]
                OStype = $vm.StorageProfile.OsDisk.OsType
                OSDiskName = $vm.StorageProfile.OsDisk.Name
                OSDiskSize = ($vmDisks | Where-Object Name -Match $vm.StorageProfile.OsDisk.Name).disksizeGB
                AttachedDataDisks = ($vm.StorageProfile.DataDisks | Measure-Object).Count
                MaxDataDiskSupported = ($vmLocations | Where-Object Name -Match $vm.HardwareProfile.VmSize).MaxDataDiskCount[0]
                PrimaryNIC = ($vmNICs | Where-Object {($_.Name -Match $vm.Name) -and ($_.Primary -eq 'True')}).Name
                PrivateIP = (($vmNICs | Where-Object Name -Match $vm.Name).ipconfigurations | Where-Object primary -EQ 'True').PrivateIpAddress
                NICsPresent = ($vmNICs | Where-Object Name -Match $vm.Name | Measure-Object).Count
             }
        }
        
        # Export VMs to csv file
        $vmInfo | Export-Csv -NoTypeInformation $ExportPath\Details-VMs.csv
        Verbose-Msg -Action "Exported" -Section "VMs" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "VMs" -Result "None"
    }


    ############# NSGs ########################################################
    
    # Verbose-Msg "Querying: NSGs"
    Verbose-Msg -Action "Querying" -Section "Network Security Groups (NSG)" -Result "Starting"

    # Get all info on the NSGs.
    $nsgResources = Get-AzNetworkSecurityGroup

    if (($nsgResources | Measure-Object).Count -ne 0 ) { 
        # Return the basic NSG information.
        $nsgResources | Export-Clixml $ExportPath\Config-NSGs.clixml

        # Return the NSG Rules for each NSG.
        $nsgSecurityRules = foreach ($nsg in $nsgResources) {
                # Store the NSG security Rule into the variable $nsgRule.
                $nsgRule = $nsg.SecurityRules

                # Foreach loop goes through the single NSG security Rule and creates a new Hash table.
                foreach ($nsgRuleItem in $nsgRule){
                    [PSCustomObject]@{
                        Priority = $nsgRuleItem.Priority
                        RuleName = $nsgRuleItem.Name
                        Direction = $nsgRuleItem.Direction
                        SourceAddress = $nsgRuleItem.SourceAddressPrefix -join ','
                        SourcePortRange = $nsgRuleItem.SourcePortRange -join ','
                        DestionAddress = $nsgRuleItem.DestinationAddressPrefix -join ','
                        DestinationPortRange = $nsgRuleItem.DestinationPortRange -join ','
                        Description = $nsgRuleItem.Description
                }
            }
        }

    $nsgSecurityRules | Export-Csv -NoTypeInformation $ExportPath\Details-NSGs.csv

    Verbose-Msg -Action "Exported" -Section "Network Security Groups (NSG)" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Network Security Groups (NSG)" -Result "None"
    }

    ############# VNETS ########################################################

    #Verbose-Msg "Querying: VNets"
    Verbose-Msg -Action "Querying" -Section "Virtual Networks (Vnet)" -Result "Starting"

    ## get vnet config
    $vnetResources = Get-AzVirtualNetwork | Sort-Object Name

    if (($vnetResources | Measure-Object).Count -ne 0 ) { 
        # Export VNet Config to file
        $vnetResources | Export-Clixml $ExportPath\Config-VNets.clixml

        # Foerach loop to get the details from the VNet and Subnets within it.
        $VNetDetails = foreach ($vnet in $vnetResources) {
            $vnetSubnetItem = $vnet.Subnets
                foreach ($subnet in $vnetSubnetItem) {
                    [PSCustomObject]@{
                        vNetName = $vnet.Name
                        vNetLocation = $vnet.Location
                        vNetAddressSpace = $vnet.AddressSpace.AddressPrefixes -join ','
                        SubnetGateway = ($subnet.NatGateway.id -split ('/'))[8]
                        Routetable = $subnet.RouteTable
                    }
                }
        }   
    # Export details File
    $VNetDetails | Export-Csv -NoTypeInformation $ExportPath\Details-VNets.csv

    Verbose-Msg -Action "Exported" -Section "Virtual Networks (Vnet)" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Virtual Networks (Vnet)" -Result "None"
    }


    ############# Nat Gateways ########################################################

    # Verbose-Msg "Querying: Nat Gateways"
    Verbose-Msg -Action "Querying" -Section "Nat Gateways" -Result "Starting"

    $natgwResources = Get-AzNatGateway
        
    if ( ($natgwResources | Measure-Object).Count -ne 0 ) {

        $natgwResources | Export-Clixml $ExportPath\Config-NatGateways.clixml
        #$NATGWs | ft -a Name,ResourceGuid,ResourceGroupName,Location,Type

        Verbose-Msg -Action "Exported" -Section "Nat Gateways" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Nat Gateways" -Result "None"
    }

    ############# Load Balancers ########################################################
    
     Re-do the foreach loop to loop through the various Load balancer items, Rules, Backends and front ends.

    #Verbose-Msg "Querying: Load Balancers"
    Verbose-Msg -Action "Querying" -Section "Load Balancers" -Result "Starting"

    $LBs = Get-AzLoadBalancer

    # Export Azure LBs Config to file
    if ( ($LBs | Measure-Object).Count -ne 0 ) { 
        $LBs | Export-Clixml $ExportPath\Config-LoadBalancers.clixml 

        
    foreach ($LB in $loadBalancerResources) {
        $loadBalancerRules = $LB.LoadBalancingRules

        foreach ($lbRule in $loadBalancerRules) {
            [PSCustomObject]@{
                SKU = $LB.Sku.Name
                SKUTier = $LB.Sku.Tier
                FrontEndName = $LB.FrontendIpConfigurations.Name
                FontEndIP = $LB.FrontendIpConfigurations.PrivateIpAddress
                BackendPoolName = $LB.BackendAddressPools.Name
                #BackendIPs =
                LBRuleName = $lbRule.Name 
                LBRuleFrontendPort = $lbRule.FrontendPort
                LBRuleBackendPort = $lbRule.BackendPort
                LBRuleProtocol = $lbrule.Protocol
                HealthProbeName = $LB.Probes.Name
                HealthProbePort = $LB.Probes.Port
            }
        }
    }

    $LBsDetails | Export-Csv -NoTypeInformation $ExportPath\Details-LoadBalancers.csv

    Verbose-Msg -Action "Exported" -Section "Load Balancers" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Load Balancers" -Result "None"
    }

    ############# VPN Gateways ########################################################

    
    #Verbose-Msg "Querying: VPN Gateways"
    Verbose-Msg -Action "Querying" -Section "VPN Gateways" -Result "Starting"

    $VPNGWs = Get-AzResource -ResourceType "Microsoft.Network/virtualnetworkgateways" | Get-AzVirtualNetworkGateway
    if ( ($VPNGWs | Measure-Object).Count -ne 0 ) { 
        $VPNGWs | Export-Clixml $ExportPath\Config-VPNGateways.clixml 
        $VPNConns = Get-AzResource -ResourceType "Microsoft.Network/connections" | Get-AzVirtualNetworkGatewayConnection
        $VPNConns | Export-Clixml $ExportPath\Config-VPNGatewayConnections.clixml
        $VPNConnsRaw = $VPNConns | Select-Object Name, Location, @{l = 'VPNGateway'; e = { $_.VirtualNetworkGateway1.id.split('/')[-1] } }, @{l = 'Remote'; e = { $_.LocalNetworkGateway2.id.split('/')[-1] } }, ConnectionStatus, *bytesTransferred
        $VPNConnsRaw | Export-Csv -NoTypeInformation $ExportPath\Details-VPNConnections.csv
        Verbose-Msg -Action "Exported" -Section "VPN Gateways" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "VPN Gateways" -Result "None"
    }


    ############# Private DNS ########################################################
    
    #Verbose-Msg "Querying: Private DNS"
    Verbose-Msg -Action "Querying" -Section "Private DNS" -Result "Starting"

    # Get Private DNS zones config
    $PrivateDNS = Get-AzDnsZone

    # Export Private DNS Config to file
    if ( ($PrivateDNS | Measure-Object).Count -ne 0 ) { 
        $PrivateDNS | Export-Clixml $ExportPath\Config-PrivateDNS.clixml
        #$PrivateDNS | ft -a 
        Verbose-Msg -Action "Exported" -Section "Private DNS" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Private DNS" -Result "None"
    }

    ############# Public DNS ########################################################
    
    #Verbose-Msg "Querying: Public DNS"
    Verbose-Msg -Action "Querying" -Section "Public DNS" -Result "Starting"

    # Get Public DNS zones config
    $PublicDNS = Get-AzDnsZone

    # Export Public DNS Config to file
    if ( ($PublicDNS | Measure-Object).Count -ne 0 ) { 
        $PublicDNS | Export-Clixml $ExportPath\Config-PublicDNS.clixml 
        #$PublicDNS | ft -a 
        Verbose-Msg -Action "Exported" -Section "Public DNS" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Public DNS" -Result "None"
    }

    ############# Vaults ########################################################
    
    #Verbose-Msg "Querying: Vaults"
    Verbose-Msg -Action "Querying" -Section "Recovery Service Vaults" -Result "Starting"

    $Vaults = Get-AzRecoveryServicesVault

    if ( ($Vaults | Measure-Object).Count -ne 0 ) { 
        $Vaults | Export-Clixml $ExportPath\Config-Vaults.clixml 
        $VaultDetails = $Vaults | Select-Object Name, ResourceGroupName, Location
        $VaultDetails | Export-Csv -NoTypeInformation $ExportPath\Details-Vaults.csv
        #$VaultDetails | ft -a 
        Verbose-Msg -Action "Exported" -Section "Vaults" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Vaults" -Result "None"
    }


    ############# Disks ########################################################
    
    #Verbose-Msg "Querying: Disks"
    Verbose-Msg -Action "Querying" -Section "Disks" -Result "Starting"

    $Disks = Get-AzDisk

    if ( ($Disks | Measure-Object).Count -ne 0 ) { 
        $Disks | Export-Clixml $ExportPath\Config-Disks.clixml 
        $DiskDetails = $Disks | Select-Object Name, ResourceGroupName, Location, TimeCreated, DiskSizeGB, Disk*Read*, DiskState, @{l = 'Sku'; e = { "$($_.Sku.name) $($_.sku.Tier)" } }
        $DiskDetails | Export-Csv -NoTypeInformation $ExportPath\Details-Disks.csv
        #$DiskDetails | group Sku | select Count,@{l='DiskType';e={$_.Name}} | ft -a 
        Verbose-Msg -Action "Exported" -Section "Disks" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Disks" -Result "None"
    }


    ############# Network Interfaces ########################################################
    
    #Verbose-Msg "Querying: Network Interfaces"
    Verbose-Msg -Action "Querying" -Section "Network Interfaces" -Result "Starting"

    $Nics = Get-AzNetworkInterface

    if ( ($Nics | Measure-Object).Count -ne 0 ) { 
        $Nics | Export-Clixml $ExportPath\Config-Nics.clixml
     
        $NicsDetails = $Nics | Select-Object Name, ResourceGroupName, Location, @{l = 'VMName'; e = { $_.VirtualMachine.id.split('/')[-1] } }, @{l = 'IPs'; e = { ($_.IpConfigurations | ForEach-Object { "$($_.privateipaddress) ($($_.PrivateIpAllocationMethod))" } ) -join ', ' } }, Primary, MacAddress, NetworkSecurityGroup, EnableIPForwarding, EnableAcceleratedNetworking
        $NicsDetails | Export-Csv -NoTypeInformation $ExportPath\Details-Nics.csv
        #$NicsDetails | ft -a 
        Verbose-Msg -Action "Exported" -Section "Network Interfaces" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Network Interfaces" -Result "None"
    }


    ############# Disk Snapshots ########################################################

    #Verbose-Msg "Querying: Disk Snapshots"
    #Verbose-Msg -Action "Querying" -Section "Disk Snapshots" -Result "Starting"


    ############# VM restore points ########################################################
    
    #Verbose-Msg "Querying: VM restore points"
    Verbose-Msg -Action "Querying" -Section "VM Restore Points" -Result "Starting"

    $RestorepointCollections = Get-AzResource  | Where-Object resourcetype -Match restorepoint | ForEach-Object { Get-AzRestorePointCollection -ResourceGroupName $_.ResourceGroupName -Name $_.Name }

    if ( ($RestorepointCollections | Measure-Object).Count -ne 0 ) { 
        $RestorepointCollections | Export-Clixml $ExportPath\Config-VMRestorePoints.clixml
     
        #$RestorepointCollectionsRaw = $RestorepointCollections 
        #$RestorepointCollectionsRaw | Export-Csv -NoTypeInformation $ExportPath\Details-VMRestorePoints.csv
        #$RestorepointCollectionsRaw 
        Verbose-Msg -Action "Exported" -Section "VM Restore Points" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "VM Restore Points" -Result "None"
    }


    ############# Resources ########################################################
    
    #Verbose-Msg "Querying: Resources"
    Verbose-Msg -Action "Querying" -Section "Resources" -Result "Starting"

    $resources = Get-AzResource 

    if ( ($resources | Measure-Object).Count -ne 0 ) { 
        $resources | Export-Clixml $ExportPath\Config-Resources.clixml
    
        $ResourcesDetails = $Resources | Group-Object resourcetype | Sort-Object count -Descending | Select-Object Count, Name
        $ResourcesDetails | Export-Csv -NoTypeInformation $ExportPath\Details-Resources.csv
        #$ResourcesDetails 
        Verbose-Msg -Action "Exported" -Section "Resources" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Resources" -Result "None"
    }


    ############# Resource Groups ########################################################
    
    #Verbose-Msg "Querying: Resource Groups"
    Verbose-Msg -Action "Querying" -Section "Resource Groups" -Result "Starting"

    $RGs = Get-AzResource 

    if ( ($RGs | Measure-Object).Count -ne 0 ) { 
        # Export to files
        $RGs | Export-Clixml $ExportPath\Config-ResourceGroups.clixml
        $RGs | Export-Csv -NoTypeInformation $ExportPath\Details-ResourceGroups.csv
        Verbose-Msg -Action "Exported" -Section "Resource Groups" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Resource Groups" -Result "None"
    }


    ############# Resource Locks ########################################################
    
    #Verbose-Msg "Querying: Resource Locks"
    Verbose-Msg -Action "Querying" -Section "Resource Locks" -Result "Starting"

    $ResLocks = Get-AzResourceLock | Sort-Object ResourceType, Name

    if ( ($ResLocks | Measure-Object).Count -ne 0 ) { 
        $ResLocks | Export-Clixml $ExportPath\Config-ResourceLocks.clixml
    
        $ResourceLocksDetails = $ResLocks | Select-Object @{l = 'Level'; e = { $_.Properties.level } }, ResourceName, Name, @{l = 'Notes'; e = { $_.Properties.notes } }, ResourceType
        $ResourceLocksDetails | Export-Csv -NoTypeInformation $ExportPath\Details-ResourceLocks.csv
        #$ResourceLocksDetails | Group Name | ft -a  Count,Name
        Verbose-Msg -Action "Exported" -Section "Resource Locks" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Resource Locks" -Result "None"
    }


    ############# SQL Databases, Servers and VMs ########################################################
    
    #Verbose-Msg "Querying: SQL Servers & Databases"

    Verbose-Msg -Action "Querying" -Section "SQL Servers" -Result "Starting"
    $SQLServers = Get-AzSqlServer  

    Verbose-Msg -Action "Querying" -Section "SQL Databases" -Result "Starting"
    $SQLDatabases = $SQLServers | Get-AzSqlDatabase 

    if ( ($SQLDatabases | Measure-Object).Count -ne 0 ) {
        $SQLServers   | Export-Clixml $ExportPath\Config-SqlServers.clixml  
        $SQLDatabases | Export-Clixml $ExportPath\Config-SqlDatabases.clixml
    
        $SQLDatabasesRaw = $SQLDatabases | Get-AzSqlDatabase | Select-Object ServerName, DatabaseName, Status, Location, DatabaseId, ResourceGroupName, CreationDate, ReadScale, ZoneRedundant, SkuName, PausedDate, ResumedDate
        $SQLDatabasesRaw | Export-Csv -NoTypeInformation $ExportPath\Details-SqlDatabases.csv
        Verbose-Msg -Action "Exported" -Section "SQL Servers & Databases" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "SQL Servers & Databases" -Result "None"
    }

    # Verbose-Msg "Querying: SQL VMs"
    Verbose-Msg -Action "Querying" -Section "SQL VMs" -Result "Starting"

    $SQLVMs = Get-AzSqlVM  


    if ( ($SQLVMs | Measure-Object).Count -ne 0 ) {
        $SQLVMs   | Export-Clixml $ExportPath\Config-SqlVMs.clixml  
    
        $SQLVMsRaw = $sqlvms | Select-Object Name, ResourceGroupName, LicenseType, Sku, Offer, SqlManagementType, @{l = 'VMId'; e = { $_.VirtualMachineId.split('/')[2] } }, @{l = 'Tags'; e = { ($_.Tags | ForEach-Object { "$($_.Keys): $($_.Values)" }) -join ', ' } }
        $SQLVMsRaw | Export-Csv -NoTypeInformation $ExportPath\Details-SqlVMs.csv
        Verbose-Msg -Action "Exported" -Section "SQL VMs" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "SQL VMs" -Result "None"
    }


    ############# Storage Accounts ########################################################
    
    #Verbose-Msg "Querying: Storage Accounts"
    Verbose-Msg -Action "Querying" -Section "Storage Accounts" -Result "Starting"

    $AzStorageAccounts = Get-AzStorageAccount


    if ( ($AzStorageAccounts | Measure-Object).Count -ne 0 ) { 
        $AzStorageAccounts | Export-Clixml $ExportPath\Config-AzStorageAccounts.clixml
    
        $AzStorageAccountsRaw = $AzStorageAccounts | Select-Object  StorageAccountName, ResourceGroupName, PrimaryLocation, SkuName, Kind, AccessTier, CreationTime, ProvisioningState, EnableHttpsTrafficOnly, LargeFileShares, CreationDate, StatusOfPrimary, StatusOfSecondary, AllowBlobPublicAccess, MinimumTlsVersion, @{l = 'Tags'; e = { ($_.Tags | ForEach-Object { "$($_.Keys): $($_.Values)" }) -join ', ' } }
        $AzStorageAccountsRaw | Export-Csv -NoTypeInformation $ExportPath\Details-AzStorageAccounts.csv
        Verbose-Msg -Action "Exported" -Section "Storage Accounts" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Storage Accounts" -Result "None"
    }

    #Verbose-Msg "Querying: Storage Account File Shares"
    Verbose-Msg -Action "Querying" -Section "Storage Account File Shares" -Result "Starting"

    $AzStorageAccountsFileShares = $AzStorageAccounts | Get-AzRmStorageShare -ErrorAction SilentlyContinue

    if ( ($AzStorageAccountsFileShares | Measure-Object).Count -ne 0 ) { 
        $AzStorageAccountsFileShares | Export-Clixml $ExportPath\Config-AzStorageAccountsFileShares.clixml
    
        $AzStorageAccountsFileSharesRaw = $AzStorageAccountsFileShares | Select-Object Name, StorageAccountName, EnabledProtocols, AccessTier, ResourceGroupName, QuotaGiB, LastModifiedTime, SnapshotTime, ShareUsageBytes, RemainingRetentionDays, Id
        $AzStorageAccountsFileSharesRaw | Export-Csv -NoTypeInformation $ExportPath\Details-AzStorageAccountsFileShares.csv
        Verbose-Msg -Action "Exported" -Section "Storage Account File Shares" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Storage Account File Shares" -Result "None"
    }

    #Verbose-Msg "Querying: Storage Account Containers"
    Verbose-Msg -Action "Querying" -Section "Storage Account Containers" -Result "Starting"

    $AzStorageAccountsContainers = $AzStorageAccounts | Get-AzRmStorageContainer -ErrorAction SilentlyContinue

    if ( ($AzStorageAccountsContainers | Measure-Object).Count -ne 0 ) { 
        $AzStorageAccountsContainers | Export-Clixml $ExportPath\Config-AzStorageAccountsContainers.clixml
    
        $AzStorageAccountsContainersRaw = $AzStorageAccountsContainers | Select-Object ResourceGroupName, StorageAccountName, Name, PublicAccess, LastModified, HasLegalHold, HasImmutabilityPolicy, Deleted, Version, @{l = 'ImmutableStorageWithVersioning'; e = { $_.ImmutableStorageWithVersioning.Enabled } }, Id
        $AzStorageAccountsContainersRaw | Export-Csv -NoTypeInformation $ExportPath\Details-AzStorageAccountsContainers.csv
        Verbose-Msg -Action "Exported" -Section "Storage Account Containers" -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Storage Account Containers" -Result "None"
    }


    ############# Recovery Vault Backups ########################################################
    
    # pre-req $Vaults = Get-AzRecoveryServicesVault
    Verbose-Msg -Action "Querying" -Section "Recovery Vault Backups" -Result "Starting"

    $AzBackups = foreach ($Vault in $Vaults) { 
        $Vault | Set-AzRecoveryServicesVaultContext 
        Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM 
        Get-AzRecoveryServicesBackupContainer -ContainerType AzureSQL
    } 

    if ( ($AzBackups | Measure-Object).Count -ne 0 ) { 
        $AzBackups | Export-Clixml $ExportPath\Config-AzRecoveryVaultBackups.clixml
    
        $AzBackupsRaw = $AzBackups | Select-Object  @{l = 'VaultName'; e = { $Vault.name } }, FriendlyName, ResourceGroupName, Status, ContainerType
        $AzBackupsRaw | Export-Csv -NoTypeInformation $ExportPath\Details-AzRecoveryVaultBackups.csv
        Verbose-Msg -Action "Exported" -Section "Recovery Vault Backups"  -Result "Completed"
    }
    else { 
        Verbose-Msg -Action "Skipped " -Section "Storage Account Containers" -Result "None"
    }


    ############# Create the excel file from the csv files ########################################################
    
    #Verbose-Msg "Querying: Loading Excel Module"
    Verbose-Msg -Action "Importing Module" -Section "Excel Powershell Module" -Result "Starting"

    Import-Module ImportExcel

    #Verbose-Msg "Querying: Exporting Excel File"
    Verbose-Msg -Action "Querying" -Section "Exporting Excel File" -Result "Starting"

    $ExcelExportFile = $ExportPath + "\$($AzContextRaw.SubscriptionName) - Azure Subscription Summary.xlsx"
    Get-ChildItem details*.csv -Path $ExportPath | Sort-Object LastWriteTime | ForEach-Object { $csv = $_ ; $Name = $csv.basename.split('-')[1] ; Import-Csv $csv.fullname  | Export-Excel $ExcelExportFile -Append -WorksheetName $Name -TableStyle Medium16 -AutoSize } 
 
    #Write-Output "Completed, see export folder: $ExportPath"
    Verbose-Msg -Action "Completed" -Section "Script has completed" -Result "Export Folder: $ExportPath"


} # End of ExportTenantConfig Function scriptblock

# run the export, depending if the -ExportAllSubscriptions commmand line option was specified.

if ($ExportAllSubscriptions) {
    # run this section if the -$ExportAllSubscriptions option has been specified. it will then connect to each subscription available and export it.
    Get-AzSubscription  | ForEach-Object { Select-AzSubscription $_.Name ; ExportTenantConfig }
}
else {
    # run this section if option not specified to do all subscriptions, so will just run against current connected one.
    ExportTenantConfig
} 

Export-Excel $ExcelExportFile -Append -WorksheetName $Name -TableStyle Medium16 -AutoSize