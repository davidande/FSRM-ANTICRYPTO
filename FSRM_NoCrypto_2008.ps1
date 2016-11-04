##############################
# FSRM_NoCrypto_2008.ps1        #
# W2008 and 2008R2           #
# may work en 2003R2         #
# David ANDE - ALTAE         #
# WWW.ALTAE.NET              #
# GNU GENERAL PUBLIC LICENSE #
##############################

# Using FSRM to Block users writing file with a forbiden extension.
# This scripts can be add as a task to check newer version of extensions list : program: c:\windows\system32\windowsPowerShell\v1.0\Powershell.exe
# Arguments to add: -noprofile  -executionpolicy Unrestricted -file "where is this script" default c:\FSRMNOCRYPTO\FSRM_NoCrypto_2008.ps1
# Before using this script, You have to install FSRM
# Add Role -> File Services/File Server Ressource Manager
# Alternative install can be done with the command: Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
# Lunch FSRM.MSC and Right Click on File Server Ressource Manager to configure Mail notification Settings
# SMTP Server, Default destination mail and sender adress
# Click on Send a test mail to check settings working and validate

########## VARIABLE TO MODIFY #############
$wkdir = "C:\FSRMNOCRYPTO"
###########################################

# verifying if new crypto extensions available #
$url = "https://fsrm.experiant.ca/api/v1/get"
$path = "$wkdir\extensions.txt"
$client = New-Object System.Net.WebClient
$client.DownloadFile($url, $path)
$dif = compare-object -referenceobject $(get-content "$wkdir\extensions.txt") -differenceobject $(get-content "$wkdir\extensions.old")
if (!$dif) { 
rm $wkdir\extensions.txt
exit }

################################ Functions ################################

function ConvertFrom-Json20([Object] $obj)
{
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return ,$serializer.DeserializeObject($obj)
}

Function New-CBArraySplit {

    param(
        $extArr,
        $depth = 1
    )

    $extArr = $extArr | Sort-Object -Unique

    # Concatenate the input array
    $conStr = $extArr -join ','
    $outArr = @()

    # If the input string breaks the 4Kb limit
    If ($conStr.Length -gt 4096) {
        # Pull the first 4096 characters and split on comma
        $conArr = $conStr.SubString(0,4096).Split(',')
        # Find index of the last guaranteed complete item of the split array in the input array
        $endIndex = [array]::IndexOf($extArr,$conArr[-2])
        # Build shorter array up to that indexNumber and add to output array
        $shortArr = $extArr[0..$endIndex]
        $outArr += [psobject] @{
            index = $depth
            array = $shortArr
        }

        # Then call this function again to split further
        $newArr = $extArr[($endindex + 1)..($extArr.Count -1)]
        $outArr += New-CBArraySplit $newArr -depth ($depth + 1)
        
        return $outArr
    }
    # If the concat string is less than 4096 characters already, just return the input array
    Else {
        return [psobject] @{
            index = $depth
            array = $extArr
        }  
    }
}

################################ Functions ################################

# Add to all drives
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -match  '0|2147483648' } | Select -ExpandProperty Path | Select -Unique
if ($drivesContainingShares -eq $null -or $drivesContainingShares.Length -eq 0)
{
    Write-Host "No drives containing shares were found. Exiting.."
    exit
}

Write-Host "The following shares needing to be protected: $($drivesContainingShares -Join ",")"


$fileGroupName = "ALTAE_CryptoBlocker_extensions"
$fileTemplateName = "ALTAE_CryptoBlocker_Template"
$fileScreenName = "ALTAE_CryptoBlockerScreen"

$webClient = New-Object System.Net.WebClient
$jsonStr = $webClient.DownloadString($url)
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })

# Split the $monitoredExtensions array into fileGroups of less than 4kb to allow processing by filescrn.exe
$fileGroups = New-CBArraySplit $monitoredExtensions
ForEach ($group in $fileGroups) {
    $group | Add-Member -MemberType NoteProperty -Name fileGroupName -Value "$FileGroupName$($group.index)"
}

# Perform these steps for each of the 4KB limit split fileGroups
ForEach ($group in $fileGroups) {
    Write-Host "#############################################"
    Write-Host "Adding/replacing File Group [$($group.fileGroupName)] with monitored file [$($group.array -Join ",")].."
    &filescrn.exe filegroup Delete "/Filegroup:$($group.fileGroupName)" /Quiet
    &filescrn.exe Filegroup Add "/Filegroup:$($group.fileGroupName)" "/Members:$($group.array -Join '|')"
}

Write-Host "Adding/replacing File Screen Template [$fileTemplateName] with Event Notification [notification.cfg] and Command Notification [$cmdConfFilename].."
&filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
Remove-Item "$wkdir\notification.cfg"
New-Item "$wkdir\notification.cfg" -type file
Add-Content "$wkdir\notification.cfg" "Notification=e"
Add-Content "$wkdir\notification.cfg" "`nRunLimitInterval=30"
Add-Content "$wkdir\notification.cfg" "`nMessage=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group. This file could be a marker for malware infection, and should be investigated immediately."
# Build the argument list with all required fileGroups
$screenArgs = 'Template','Add',"/Template:$fileTemplateName"
ForEach ($group in $fileGroups) {
    Write-Host "#############################################"
    $screenArgs += "/Add-Filegroup:$($group.fileGroupName)"
}

&filescrn.exe $screenArgs /Add-Notification:"e,$wkdir\notification.cfg"
$drivesContainingShares | % {
    Write-Host "#############################################"
    Write-Host "`Adding/replacing File Screen for [$_] with Source Template [$fileTemplateName].."
    &filescrn.exe Screen Delete "/Path:$_" /Quiet
    &filescrn.exe Screen Add "/Path:$_" "/SourceTemplate:$fileTemplateName"
}
# Keeping list to compare next #
#time with new one #
if (Test-Path "$wkdir\extension.old") 
{
    rm $wkdir\extensions.old
}
Else  
{
cp $wkdir\extensions.txt $wkdir\extensions.old
rm $wkdir\extensions.txt
echo finish
}
Exit
