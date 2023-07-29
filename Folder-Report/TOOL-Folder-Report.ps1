###### Prompt user for flder input. ######
$sourceDirectory = Read-Host -Prompt "Please enter the directory you wish to scan"

###### Get all Directories in that location. ######
$ChildDirectories = Get-ChildItem $sourceDirectory | `
                        Where-Object {$_.PSIsContainer -eq $true} | `
                        Sort-Object Name

###### Foreach directory get all items recursively. ######
$childDirectorySizes = foreach ($folder in $ChildDirectories) {

    $subFolderItems = Get-ChildItem $folder.FullName -recurse -force | `
    Where-Object {$_.PSIsContainer -eq $false} | `
    Measure-Object -property Length -sum | `
    Select-Object Sum  
    
    New-Object psobject -property @{
        "Location" = $folder.FullName
        "Size(MB)" = [Math]::Round($subFolderItems.sum /1MB, 2)
    }
}

###### Provide a size report of the directory and child directories. ######
$childDirectorySizes | Format-Table 'Location','Size(MB)' -AutoSize