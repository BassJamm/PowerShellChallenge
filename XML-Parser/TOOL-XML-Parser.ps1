# Import the log file content.
[xml]$logFileContent = Get-Content -Path 'C:\Git\PowerShellChallenge\XML-Parser\Dummy copy.xml'

$logFileContent.users.user.Username | Foreach-Object  {
  [[PSCustomObject]@{
    UserName = $_.Username
    
  }]
}