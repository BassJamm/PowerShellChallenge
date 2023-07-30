# Import the content of the log file into variable.
$logFileContent = Get-Content -Path C:\GitRepos\PowerShellChallenge\Log-File-Parser\ApplicationLogFile.txt

# Identidy and remove useless characters, then identify each row.
$logfileData = $logFileContent -replace "\[LOG\]","" -replace "\[","" -replace "\]","" -split "(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s-\s.*)"
$rows = $logfileData | Where-Object { $_ -match "(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s-\s.*)"} 

# Seperate strings into columns.
$regexDate = "[\d]{4}-[\d]{2}-[\d]{2}"
$regexTime = "[\d]{2}:[\d]{2}:[\d]{2}"
$regexMessage = "[^-]*$"

$tableOutput = foreach ($row in $rows) {

    [PSCustomObject]@{
        Date = ($row | Select-String -Pattern $regexDate).Matches.Value
        Time = ($row | Select-String -Pattern $regexTime).Matches.Value
        Message = ($row | Select-String -Pattern $regexMessage).Matches.Value

    }
}