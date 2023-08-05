###### Prompt user for flder input. ######
$sourceDirectory = Read-Host -Prompt "Please enter the directory you wish to scan"

###### Get all Directories in that location. ######
Write-Host "Collecting the diretory information." -ForegroundColor Yellow
$ChildDirectories = (Get-ChildItem $sourceDirectory -Directory).FullName
Start-Sleep 1
Write-Host "Directories found successfully." -ForegroundColor Green

###### Foreach directory get all items recursively. ######
Write-Host "Processing items." -ForegroundColor Yellow
$childDirectorySizes = foreach ($folder in $ChildDirectories) {
    [PSCustomObject]@{
        "Location" = $folder
        "FileItems" = (Get-ChildItem $folder -recurse -force | Where-Object {$_.PSIsContainer -eq $false} | Measure-Object | Select-Object Count).Count
        "Size(MB)" = [Math]::Round((Get-ChildItem $folder -recurse -force | Where-Object {$_.PSIsContainer -eq $false} | Measure-Object -property Length -sum | Select-Object Sum).Sum /1MB, 3)
    }

}
Write-Host "All subdirectories processed successfully." -ForegroundColor Green
###### Provide a size report of the directory and child directories. ######
$childDirectorySizes | Format-Table * -AutoSize
