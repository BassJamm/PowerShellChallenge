[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)][Switch]$AllRecentEvents,
    [Parameter(Mandatory = $false)][String]$KeyWordSearch,
    [Parameter(Mandatory = $false)][String]$IDSearch,
    [Parameter(Mandatory = $true)][String]$NumberofEvents
)

########## Variable to get the generic even logs. ##########
$logNames = @(
    'Application',
    'System',
    'Security',
    'Setup'
)
########## Variable to get list of properties to retrieve. ##########
$properties = @(
    'LogName',
    'timeCreated',
    'id',
    'leveldisplayname',
    'message'
)

########## Functions. ##########

<# Search for all first 10 events in each of the generic logs. #>
function AllRecentEvents ($ExportAll) {

    $eventsReport = foreach ($log in $logNames) {
        Write-Host "Collecting events from $($log)" -ForegroundColor Yellow
        Get-WinEvent -LogName $log -MaxEvents $NumberofEvents | Select-Object $properties
        
    }

    $exportToFile = Read-Host -Prompt "Do you want to export these events to file? (Yes\No)"
    if ($exportToFile -eq 'Yes') {
        $eventsReport | Format-Table * -AutoSize
        Start-Sleep 1
        Write-Host "Exporting data to location, C:\Temp\." -ForegroundColor Yellow
        $eventsReport | Format-List | Out-File -Path C:\Temp\All-Event-Logs-$((Get-Date).ToString("dd-MM-yy_hh-mm-ss")).txt -Append
    }
    else {
        $eventsReport | Format-Table * -AutoSize
    }
        
}
<# Search for a keyword in the message field of the generic logs. #>
function KeyWordSearch {
    
    $eventsReport = foreach ($log in $logNames) {
        
        $events = Get-WinEvent -LogName $log -MaxEvents $NumberofEvents  | Where-Object Message -Match $KeyWordSearch | Select-Object $properties | Format-List

        if (($events | Measure-Object).Count -ne 0) {
            Write-Host "Events found in $($log) matching reference $($KeyWordSearch)" -ForegroundColor Magenta
            $events
        }
        else {
            Write-Host "No references found in $($log)" -ForegroundColor Red
        }
    }

    $exportToFile = Read-Host -Prompt "Do you want to export these events to file? (Yes\No)"
    if ($exportToFile -eq 'Yes') {
        $eventsReport
        Start-Sleep 1
        Write-Host "Exporting data to location, C:\Temp\." -ForegroundColor Yellow
        $eventsReport | Out-File -Path C:\Temp\Event-Logs-$((Get-Date).ToString("dd-MM-yy_hh-mm-ss")).txt -Append
    }
    else {
        $eventsReport
    }
    
}

<# Search for an Event ID in the message field of the generic logs. #>
function IDSearch {
   
    foreach ($log in $logNames) {
        
        $events = Get-WinEvent -LogName $log -MaxEvents $NumberofEvents  | Select-Object $properties | Where-Object id -EQ $IDSearch | Format-List
        if (($events | Measure-Object).Count -ne 0) {
            Write-Host "Events found in $($log) matching Event ID $($IDSearch)" -ForegroundColor Green
            $events
        }
        else {
            Write-Host "No references found in $($log)" -ForegroundColor Red

        }
    }   
    
}

########## If statements to run the Functions. ##########
if ($AllRecentEvents) {
    # Run the function AllRecentEvents.
    AllRecentEvents
}
if ($KeyWordSearch) {
    # Run the function KeyWordSearch.
    KeyWordSearch
}
if ($IDSearch) {
    # Run the function IDSearch.
    IDSearch
}