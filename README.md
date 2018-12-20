# Filemaker-Powershell

Use this Powershell Class to Query Filemaker Databases:

Requirements:

At least powershell v5

Filemaker Server 14 or above

XML Web Publishing enabled on your server

Example uses:

1. Query a database named "People.fmp12" that has a layout named "my_people" for someone with First Name John, Last name Doe:

. '\\path\to\fmq.ps1'

$fm = [fmq]::New('People','my_people')

$fm.AddParam('First_Name','John')

$fm.AddParam('Last_Name','Doe')

$results = $fm.sendRequest("find")


the $results will be an array of records that each contain all of the fields and values that were on the 'my_people' layout for 
So you could then access and display them in a number of ways, but here is one:

if($result.count) { #if records were found

    foreach($data in $result) {

        Write-Host $data['First_Name'] $data['Last_Name']

    }

}

See PDF Documentation for detailed info and more examples
