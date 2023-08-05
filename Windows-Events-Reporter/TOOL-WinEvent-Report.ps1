[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)][Switch]$AllRecentEvents,
    [Parameter(Mandatory=$false)][String]$KeyWordSearch,
    [Parameter(Mandatory=$false)][String]$IDSearch,
    [Parameter(Mandatory=$true)][String]$NumberofEvents
)
########## Functions. ##########
<# Search for all first 10 events in each of the generic logs. #>
function AllRecentEvents ($ExportAll) {
    ########## Get the generic even logs. ##########
    $logNames = @(
        'Application',
        'System',
        'Security',
        'Setup'
    )
    ########## List of properties to retrieve. ##########
    $properties = @(
        'LogName',
        'timeCreated',
        'id',
        'leveldisplayname',
        'message'
    )

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
    } else {
        $eventsReport | Format-Table * -AutoSize
    }
        
}
<# Search for a keyword in the message field of the generic logs. #>
function KeyWordSearch {
    ########## Get the generic even logs. ##########
    $logNames = @(
        'Application',
        'System',
        'Security',
        'Setup'
    )
    ########## List of properties to retrieve. ##########
    $properties = @(
        'LogName',
        'timeCreated',
        'id',
        'leveldisplayname',
        'message'
    )

   $eventsReport = foreach ($log in $logNames) {
        
        $events = Get-WinEvent -LogName $log -MaxEvents $NumberofEvents  | Where-Object Message -match $KeyWordSearch | Select-Object $properties | Format-List

        if (($events | Measure-Object).Count -ne 0) {
            Write-Host "Events found in $($log) matching reference $($KeyWordSearch)" -ForegroundColor Magenta
            $events
        } else {
            Write-Host "No references found in $($log)" -ForegroundColor Red
        }
    }

    $exportToFile = Read-Host -Prompt "Do you want to export these events to file? (Yes\No)"
    if ($exportToFile -eq 'Yes') {
        $eventsReport
        Start-Sleep 1
        Write-Host "Exporting data to location, C:\Temp\." -ForegroundColor Yellow
        $eventsReport | Out-File -Path C:\Temp\Event-Logs-$((Get-Date).ToString("dd-MM-yy_hh-mm-ss")).txt -Append
    } else {
        $eventsReport
    }
    
}

<# Search for an Event ID in the message field of the generic logs. #>
function IDSearch {
    ########## Get the generic even logs. ##########
    $logNames = @(
        'Application',
        'System',
        'Security',
        'Setup'
    )
    ########## List of properties to retrieve. ##########
    $properties = @(
        'LogName',
        'timeCreated',
        'id',
        'leveldisplayname',
        'message'
    )

    foreach ($log in $logNames) {
        
        $events = Get-WinEvent -LogName $log -MaxEvents $NumberofEvents  | Select-Object $properties | Where-Object id -eq $IDSearch | Format-List
        if (($events | Measure-Object).Count -ne 0) {
            Write-Host "Events found in $($log) matching Event ID $($IDSearch)" -ForegroundColor Green
            $events
        } else {
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