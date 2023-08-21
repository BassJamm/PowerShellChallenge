
#################### Connect to Tenant. ####################
Write-Host "Connecting to Tenant." -ForegroundColor Yellow
$tenantID = "6d05c462-2956-4ec4-a0d4-480181c849f9"

# Mg Graph connection permissions.
$scopes = @("User.Read.All",
    "DeviceManagementRBAC.Read.All",
    "DeviceManagementServiceConfig.Read.All",
    "DeviceManagementConfiguration.Read.All",
    "DeviceManagementManagedDevices.Read.All"
    "Directory.Read.All",
    "Group.Read.All",
    "GroupMember.Read.All",
    "Application.Read.All"
)
# Connect with the relevant permission to read all user and device data.
Connect-MgGraph -TenantId $tenantID -Scopes $scopes

# Get all Intune Groups.
Write-Host "Getting all of the Groups in Azure AD" -ForegroundColor Yellow 
$allAADGroups = Get-MgGroup -All
$groupCount = ($allAADGroups | Measure-Object).Count
Write-Host "Found $($groupCount) groups." -ForegroundColor Green

########## Get app assignments ###########

# Get the list of apps.
$applications = Get-MgDeviceAppManagementMobileApp -All
# Print to console the basic information
$applications | Select-Object Id, DisplayName, CreatedDateTime | Sort-Object CreatedDateTime | Format-Table -a
# Prompt for app ID.
$appID = Read-Host -Prompt "Enter App ID"
# Check for groups.
$appAssignments = Get-MgDeviceAppManagementMobileAppAssignment -MobileAppId $appID
foreach ($group in $appAssignments) {
    [PSCustomObject]@{
        AppName = $applications | Where-Object 
    }
    $allAADGroups | Where-Object ID -like $group.ID.Split("_")[0] | Select-Object DisplayName
}





