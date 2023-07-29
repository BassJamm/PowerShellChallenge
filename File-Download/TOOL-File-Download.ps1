<# Parameter List #>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Source,
    [Parameter()]
    [string] $Destination,
    [Parameter()]
    [string] $JobName,
    [Parameter()]
    [switch] $RunningJobs,
    [Parameter()]
    [switch] $JobHistory,
    [Parameter()]
    [String] $CancelJob,
    [Parameter()]
    [string] $MultiJobDownload
)
###### Download a file. ######
if ($Source) {
    <# Action to perform if the condition is true #>
    try {
        Start-BitsTransfer -Source $Source -Destination $Destination -TransferType Download -Asynchronous -DisplayName $JobName
        Write-Host "Beginning download from $($Source)."
        Write-Host "" # This just adds some more space in the console.

    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Error when starting the job."
        $_
    }
}

###### Add the ability to review in-progress download job(s). ######
if ($RunningJobs) {
    <# Action to perform if the condition is true #>
    Write-Host "Getting running downloads."
    Write-Host "" # This just adds some more space in the console.
    Get-BitsTransfer | Where-Object JobState -EQ 'transferring' | Format-Table JobId, CreationTime,DisplayName,TransferType,JobState,BytesTransferred,BytesTotal -AutoSize
}

##### Download multiple files. ######
if ($MultiJobDownload) {
    <# Action to perform if the condition is true #>
    try {
        Import-csv -Path $MultiJobDownload | Start-BitsTransfer -Asynchronous
        Write-Host "Beginning download from listed sources."
        Write-Host "" # This just adds some more space in the console.
        Start-Sleep 1
        Write-Host " Sources and destinations below: -"
        Get-Content -Path $MultiJobDownload

    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Error when starting the job."
        $_
    }
}

###### Add the ability to review historic job(s). ######
if ($JobHistory) {
    <# Action to perform if the condition is true #>
    Write-Host "Getting historic downloads."
    Get-BitsTransfer | Sort-Object CreationTime -Descending | Format-Table JobId, CreationTime,DisplayName,TransferType,JobState,BytesTransferred,BytesTotal -AutoSize
}

###### Add the ability to cancel job(s). ######
if ($CancelJob) {
    <# Action to perform if the condition is true #>

    try {
        Get-BitsTransfer -Name $CancelJob | Remove-BitsTransfer
        Write-Host "Job cancelled successfully." -ForegroundColor Green
        Write-Host "" # This just adds some more space in the console.
        Start-sleep 2
        Write-Host "Remaining jobs listed below." -ForegroundColor Yellow
        Write-Host "" # This just adds some more space in the console.
        Start-sleep 1
        Get-BitsTransfer | Where-Object JobState -EQ 'transferring' | Format-Table JobId, CreationTime,DisplayName,TransferType,JobState,BytesTransferred,BytesTotal -AutoSize

    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Error when cancelling job."
        $_
    }

}
