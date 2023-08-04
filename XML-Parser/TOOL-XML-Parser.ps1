# Import the XMl file, the [XML] part tells PowerShell what to do with the data
# and turns the XML file back nto PowerShell objects where it can.
[xml]$xmlFileHarder = Get-content -Path .\XML-Parser\Multiple-Depth-File.xml

# We're iterating through the objects stored in the $xmlFileHarder variable,
# flattening the structure into one object; which is easier to manipulate.
$xmlReport2 = foreach ($item in $xmlFileHarder.users.user){

    [PSCustomObject]@{
        ID = $item.id
        Name = $item.name
        Age = $item.age
        Email = $item.email
        Mobile = $item.phone.mobile
        LandLine = $item.phone.home
        city = $item.location.city
        Country = $item.location.country
        ZipCode = $item.location.zipcode
    }
}
$xmlReport2 | Format-Table -AutoSize