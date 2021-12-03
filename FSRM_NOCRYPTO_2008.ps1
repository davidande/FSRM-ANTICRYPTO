##############################
# FSRM_NoCrypto_2008.ps1     #
# W2008 and 2008R2           #
# may work en 2003R2         #
# David ANDE                 #                         #
# GNU GENERAL PUBLIC LICENSE #
##############################


# First of all powershell 3 or higher is needed
# This scripts is not compatible with Powershell v2

$powershellVer = $PSVersionTable.PSVersion.Major

if ($powershellVer -le 2)
{
    Write-Host "`n####"
    Write-Host "ERROR: PowerShell v3 or higher required."
    exit
}


########## VARIABLE TO MODIFY #############
# $wkdir is where the scripts are
# better using this one
$wkdir = "C:\FSRMNOCRYPTO"

# $url is where to donwload extensionnlist from
# don't change if You don't know what You are doing
$url = "https://fsrm.experiant.ca/api/v1/get"

###########################################
# Drives to exclude for FSRM bloking
# If You want to exclude complete Path or special directory so write for exemple "C:\share" for  specific share 
# or "D:\shar*" for all shares in D starting by shar or "E:\*" for all shares in E
# or"D:\*shar*"for all shares in D containing shar.
# If nothing to exclude let the value to "0". only one value per line so only 2 exclusions for the moment :-)
# ex: $drive_exclu1= "C:\Windows*"
$drive_exclu1 = "0"
$drive_exclu2 = "0"
#############################################
If ((Test-Path "$wkdir\extensions.old") -eq $True) 
    {
        Write-Host "extensions.old founded"
    } 
else 
    {
        New-Item -ItemType "file" "$wkdir\extensions.old"
        Add-Content -path "$wkdir\extensions.old" -value "exemple"
        
    }

$taille = Get-Item "$wkdir\extensions.old" | Select Mode,Length | Select -ExpandProperty Length

If ($taille -lt 1) 
    {
        Add-Content -path "$wkdir\extensions.old" -value "exemple"
        Write-Host "Extensions.old fixed"
    }
else
    {
        Write-Host "extensions.old not empty Good"
    }
    
# verifying if new crypto extensions available #
try
{
Invoke-WebRequest $url -OutFile $wkdir\extensions.txt

$dif = compare-object -referenceobject $(get-content "$wkdir\extensions.txt") -differenceobject $(get-content "$wkdir\extensions.old")

if (!$dif) { 
Write-Host "`n####"
Write-Host "No new extensions to apply - Quit"
rm $wkdir\extensions.txt
exit 
}
}
Catch
{
Write-Host "`n####"
Write-Host "Remote extension list Offline - Quit"
If (Test-Path "$wkdir\extensions.txt")
{rm $wkdir\extensions.txt}

else
{
exit 
}
}

################################ Functions ################################

function ConvertFrom-Json20([Object] $obj)
{
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return ,$serializer.DeserializeObject($obj)
}

Function New-CBArraySplit
{
   
    param(
        $Extensions
    )

    $Extensions = $Extensions | Sort-Object -Unique

    $workingArray = @()
    $WorkingArrayIndex = 1
    $LengthOfStringsInWorkingArray = 0

    $Extensions | ForEach-Object {

        if (($LengthOfStringsInWorkingArray + 1 + $_.Length) -gt 4000) 
        {   
            # Adding this item to the working array (with +1 for a comma)
            # pushes the contents past the 4Kb limit
            # so output the workingArray
            [PSCustomObject]@{
                index = $WorkingArrayIndex
                FileGroupName = "$Script:FileGroupName$WorkingArrayIndex"
                array = $workingArray
            }
            
            # and reset the workingArray and counters
            $workingArray = @($_) # new workingArray with current Extension in it
            $LengthOfStringsInWorkingArray = $_.Length
            $WorkingArrayIndex++

        }
        else #adding this item to the workingArray is fine
        {
            $workingArray += $_
            $LengthOfStringsInWorkingArray += (1 + $_.Length)  #1 for imaginary joining comma
        }
    }

    # The last / only workingArray won't have anything to push it past 4Kb
    # and trigger outputting it, so output that one as well
    [PSCustomObject]@{
        index = ($WorkingArrayIndex)
        FileGroupName = "$Script:FileGroupName$WorkingArrayIndex"
        array = $workingArray
    }
}

################################ Functions ################################

# Add to all drives
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -match  '0|2147483648' } | Select -ExpandProperty Path | Select -Unique
if ($drivesContainingShares -eq $null -or $drivesContainingShares.Length -eq 0)
{
    Write-Host "No drives containing shares were found. Exiting.."
    rm $wkdir\extensions.txt
    exit
}
$drivesContainingShares >> "$wkdir\drivesbase.txt"
if ($drive_exclu2 -ne '0' ) {
    $drives_filter = (Get-Content "$wkdir\drivesbase.txt" | where { $_ -notlike "$drive_exclu1"} | where { $_ -notlike "$drivee_xclu2"})
    $drivesContainingShares = $drivesfilter}
    Else {
    if ($drive_exclu1 -ne '0') {
    $drivesfilter = (Get-Content "$wkdir\drivesbase.txt" | where { $_ -notlike "$drive_exclu1"})
    $drivesContainingShares = $drivesfilter}
    Else {
    }
    }
Write-Host "Shared filtered"
if ($drivesContainingShares -eq $null -or $drivesContainingShares.Length -eq 0)
{
    Write-Host "No drives containing shares were found. Exiting.."
	cp $wkdir\extensions.txt $wkdir\extensions.old
	rm $wkdir\drivesbase.txt
	rm $wkdir\extensions.txt
echo finish
    exit
}

Write-Host "The following shares needing to be protected: $($drivesContainingShares -Join ",")"


$fileGroupName = "CryptoBlocker_extensions"
$fileTemplateName = "CryptoBlocker_Template"
$fileScreenName = "Crypto_Blocker_Filter"

# old download method
# $webClient = New-Object System.Net.WebClient
# $jsonStr = $webClient.DownloadString($url)
Try
{
$jsonStr = Invoke-WebRequest -Uri $url
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })
$monitoredExtensions >> "$wkdir\extsbase.txt"
$ext_filter = Compare-Object $(Get-content "$wkdir\extsbase.txt") $(Get-content "$wkdir\ext_to_accept.txt") -IncludeEqual | where-object {$_.SideIndicator -eq "<="} | select InputObject | select -ExpandProperty InputObject
}
Catch
{
Write-Host Remote extension list Offline - Quit
rm $wkdir\drivesbase.txt
rm $wkdir\extensions.txt
exit
}

# Split the $monitoredExtensions array into fileGroups of less than 4kb to allow processing by filescrn.exe
$fileGroups = New-CBArraySplit $ext_filter
ForEach ($group in $fileGroups) {
    # $group | Add-Member -MemberType NoteProperty -Name fileGroupName -Value "$FileGroupName$($group.index)"
}

# Perform these steps for each of the 4KB limit split fileGroups
ForEach ($group in $fileGroups) {
    Write-Host "`n####"
    Write-Host "Adding/replacing File Group [$($group.fileGroupName)] with monitored file [$($group.array -Join ",")].."
    &filescrn.exe filegroup Delete "/Filegroup:$($group.fileGroupName)" /Quiet
    &filescrn.exe Filegroup Add "/Filegroup:$($group.fileGroupName)" "/Members:$($group.array -Join '|')"
}

Write-Host "Adding/replacing File Screen Template [$fileTemplateName] with Event Notification [notification.cfg] and Command Notification [$cmdConfFilename].."
&filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
Remove-Item "$wkdir\notification.cfg"
Start-Sleep -Seconds 3
New-Item "$wkdir\notification.cfg" -type file
Add-Content "$wkdir\notification.cfg" "Notification=e"
Add-Content "$wkdir\notification.cfg" "`nRunLimitInterval=30"
Add-Content "$wkdir\notification.cfg" "`nMessage=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group. This file could be a marker for malware infection, and should be investigated immediately."
# Build the argument list with all required fileGroups
$screenArgs = 'Template','Add',"/Template:$fileTemplateName"
ForEach ($group in $fileGroups) {
    Write-Host "`n####"
    $screenArgs += "/Add-Filegroup:$($group.fileGroupName)"
}

&filescrn.exe $screenArgs /Add-Notification:"e,$wkdir\notification.cfg"
$drivesContainingShares | % {
    Write-Host "`n####"
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
rm $wkdir\drivesbase.txt
rm $wkdir\extsbase.txt
rm $wkdir\extensions.txt
Write-Host "Done"
}
Exit
