[CmdletBinding()]
param (
    # Collect the log file location.
    [Parameter(Mandatory=$true)]
    [String]$LogFile,
    # Keyword to search by.
    [Parameter()]
    [String]$errorMessageKeyWord,
    # Print to Console.
    [Parameter()]
    [switch]$OutputToConsole
)

# Import the log file content.
$logFileContent = Get-Content -Path $LogFile

###### Identidy and remove useless characters, then identify each row. ######

# Identiies a row Group, denoted by the brackets at the start and end.
$regedIdentifyRows = "(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s-\s.*)"
# Removes the characters and then splits the rows by the regex patterns.
$logfileData = $logFileContent -replace "\[LOG\]","" -replace "\[","" -replace "\]","" -split $regedIdentifyRows
# This removes the empty rows that the process above creates. Need to look into that.
$rows = $logfileData | Where-Object { $_ -match "(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s-\s.*)"}

###### Identify the column data. ######

# Identifies the date characters.
$regexDate = "[\d]{4}-[\d]{2}-[\d]{2}"
# Identifies the time characters.
$regexTime = "[\d]{2}:[\d]{2}:[\d]{2}"
# Identifies the message string after the -.
$regexMessage = "[^-]*$"                                                                                            

###### Create a table. ######

# Loop through each row and store the output in the variable $tableOutput.
$tableOutput = foreach ($row in $rows) {

    # Creates a new custom object, with the properties denoted in the array.
    [PSCustomObject]@{
        Date = ($row | Select-String -Pattern $regexDate).Matches.Value
        Time = ($row | Select-String -Pattern $regexTime).Matches.Value
        Message = ($row | Select-String -Pattern $regexMessage).Matches.Value

    }
}

if ($errorMessageKeyWord) {
    $tableOutput | Where-Object Message -Like "*$errorMessageKeyWord*"
}

if ($OutputToConsole) {
    <# Action to perform if the condition is true #>
    $tableOutput | Sort-Object Date,time | Format-Table -AutoSize
}