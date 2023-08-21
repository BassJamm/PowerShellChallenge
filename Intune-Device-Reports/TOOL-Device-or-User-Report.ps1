#################### Globally used Variables. ####################

$tenantID = "92f57126-1c68-4e51-8085-5cb2e14cc381" #Read-Host -Prompt "Please enter the Tenant ID"

# Get all Intune Groups.
Write-Host "Getting all of the Groups in Azure AD" -ForegroundColor Yellow 
$allAADGroups = Get-MgGroup -All
$groupCount = ($allAADGroups | Measure-Object).Count
Write-Host "Found $($groupCount) groups." -ForegroundColor Green

# Set the report Location.
$reportlocation = "C:\IntuneReport"


#################### Connect to Tenant. ####################
Write-Host "Connecting to Tenant." -ForegroundColor Yellow

# Mg Graph connection permissions.
$scopes = @("User.Read.All",
    "DeviceManagementRBAC.Read.All",
    "DeviceManagementServiceConfig.Read.All",
    "DeviceManagementConfiguration.Read.All",
    "DeviceManagementManagedDevices.Read.All"
    "Directory.Read.All",
    "Group.Read.All",
    "GroupMember.Read.All"
)
# Connect with the relevant permission to read all user and device data.
Connect-MgGraph -TenantId $tenantID -Scopes $scopes

#################### Device Information. ####################
function DeviceSearch {
    
    ##### Get basic Device Information. #####
    
    $deviceID = "75f4a0ee-d801-4bd5-8fb6-2cb7f04bbe0e" #Read-Host -Prompt "Enter Device ID"
    
    $deviceProperties = @(
        'DeviceName',
        'UserPrincipalName',
        'EnrolledDateTime',
        'ComplianceState',
        'IsEncrypted',
        'Id',
        'Manufacturer',
        'Model',
        'OperatingSystem',
        'OSVersion',
        'SerialNumber',
        @{l = 'PrimaryUser'; e = { $device = $_; Get-MgDeviceManagementManagedDeviceUser -ManagedDeviceId $device.id | Select-Object -ExpandProperty UserPrincipalName } }
    )
    
    $deviceInfo = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceID | Select-Object $deviceProperties
    $deviceInfo | Format-List
        
    ##### Search for device or user memberships. #####

    Write-Host "Getting group memberships for the Device ID submitted." -ForegroundColor Yellow
    Write-Host "$($groupCount) groups found." -ForegroundColor Yellow
    Write-Host "Please wait whilst the groups are searched, this takes around 30s per 400 groups." -ForegroundColor Yellow

    # Loop through the groups and get the members.
    $groupMembershipOutput = foreach ($group in $allAADGroups) {

        # Get the group members.
        $groupmembers = Get-MgGroupMember -GroupId $group.ID

        # Get the number of members for each group to update the console.
        $numberofMembers = ($groupmembers | Measure-Object).Count
        
        foreach ($member in $groupmembers) {
            # Create a new hash table with the properties we want.
            [PSCustomObject]@{
                GroupName = $group.DisplayName
                Name      = $member.additionalProperties.displayName
                Type      = ($member.additionalProperties.'@odata.type').split(".")[-1]

            }
        }
    }

    Write-Host "All group members enumerated successfully." -ForegroundColor Green
    Start-Sleep 1
    Write-Host "Searching for your keyword, $($keywordSearch)." -ForegroundColor Yellow
    Start-Sleep 2
    # Search the output for the keyword.
    $groupMembershipOutput | Where-Object Name -Like $deviceInfo.DeviceName | Sort-Object GroupName | Format-Table -AutoSize

    ##### Get Compliancy Assignments. #####

    # Get all Compliancy Policies.
    $compliancyPolicies = Get-MgDeviceManagementDeviceCompliancePolicy -All | Select-Object Id, DisplayName, LastModifiedDateTime

    # Loop through the policies amd get the group assignments, store values in the $policyAssigmnets.
    $policyAssigmnets = foreach ($policy in $compliancyPolicies) {

        # Grab the assignments.
        $assignments = (Get-MgDeviceManagementDeviceCompliancePolicyAssignment -DeviceCompliancePolicyId $policy.Id).Id.Split("_")[-1]

        # Loop through the assignments and get the Group Name.
        foreach ($assignment in $assignments) {

            $GroupName = $allAADGroups | Where-Object Id -EQ $assignment

            [PSCustomObject]@{
                Compliance_Policy_Name = $policy.DisplayName
                Group_Assignment       = $GroupName.DisplayName
            }
        }
    }

    $policyAssigmnets | Sort-Object Policy_Name -Descending | Format-Table -AutoSize
    
}



