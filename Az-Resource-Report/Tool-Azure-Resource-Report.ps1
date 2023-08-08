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

        # Array for the attributes to select from variable $pips.
        $pipAttributes = @(
            'Name',
            'Location',
            'IPAddress',
            'PublicIpAllocationMethod',
            @{l= 'SKU-Name'; e= { "$($_.Sku.name)" }},
            @{l= 'SKU-Tier'; e= { "$($_.sku.Tier)" }},
            @{l= 'FQDN'; e= { $_.dnssettings.fqdn }}
        )
        # Select the attributes from $pips using the array above.
        $pips | Format-List $pipAttributes
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
        $vmInfo | Format-Table * -AutoSize
    }

}
