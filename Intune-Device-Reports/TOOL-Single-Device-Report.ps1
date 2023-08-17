########## Connect to Tenat. ##########

# Tenant ID to connect to.
$tenantID = "92f57126-1c68-4e51-8085-5cb2e14cc381"

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

########## Get Single Device Information. ##########

function singleDeviceinfo {

    $deviceID = Read-Host -Prompt "Enter Device ID"

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

    Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceID | Select-Object $deviceProperties | Format-List

}

########## Search for device or user memberships. ##########

function GetGroupMemberships {

    $keywordSearch = Read-Host -Prompt "Enter a keyword to search for, for example, william hornsby or FW123456, enter the users full name"

    # Get all Intune Groups.
    Write-Host "Getting all of the Groups in Azure AD" -ForegroundColor Yellow
    $allAADGroups = Get-MgGroup -All
    # Get a count of the groups found.
    $groupCount = ($allAADGroups | Measure-Object).Count
    Write-Host "Found $($groupCount) groups." -ForegroundColor Green

    Write-Host "Getting all of the group members, this'll take a minute." -ForegroundColor Yellow
    Start-Sleep 2

    # Loop through the groups and get the members.
    $output = foreach ($group in $allAADGroups) {
        # Get the group members.
        $groupmembers = Get-MgGroupMember -GroupId $group.ID
        $numberofMembers = ($groupmembers | Measure-Object).Count
        Write-Host "Found $($numberofMembers) objects for group $($group.DisplayName)" -ForegroundColor Cyan

        foreach ($member in $groupmembers) {
            # Create a new hash table with the properties we want.
            [PSCustomObject]@{
                GroupName = $group.DisplayName
                Name      = $member.additionalProperties.displayName
                Type      = ($member.additionalProperties.'@odata.type').split(".")[-1]

            }
        }
    }

    Write-Host "Searching for your keyword, $($keywordSearch)." -ForegroundColor Yellow
    Start-Sleep 2
    # Search the output for the keyword.
    $output | Where-Object Name -Like $keywordSearch | Sort-Object GroupName | Format-Table -AutoSize

}


########## Get Compliancy Assignments. ##########

# Get all Intune Groups.
$allAADGroups = Get-MgGroup -All

# Get all Compliancy Policies.
$compliancyPolicies = Get-MgDeviceManagementDeviceCompliancePolicy -All | Select-Object Id, DisplayName, LastModifiedDateTime

# Loop through the policies amd get the group assignments, store values in the variable.
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
