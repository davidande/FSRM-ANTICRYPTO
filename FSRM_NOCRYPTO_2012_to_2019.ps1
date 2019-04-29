##############################
# FSRM_NOCRYPTO_2012_to_2019 #
# W2012, 2012R2 2016 2019    #
# David ANDE - ALTAE         #
# WWW.ALTAE.NET              #
# GNU GENERAL PUBLIC LICENSE #
##############################


# First of all powershell 3 or higher is needed
# This scripts is not compatible with Powershell v2

$powershellVer = $PSVersionTable.PSVersion.Major

if ($powershellVer -le 2)
{
    
    Write-Host "ERROR: PowerShell v3 or higher required."
    pause
    exit
}

########## VARIABLE TO MODIFY #############
# $wkdir is where the scripts are
# better using this one
$wkdir = "C:\FSRMNOCRYPTO"

# $url is where to donwload extensionnlist from
# don't change if You don't know what You are doing
$url = "https://fsrm.experiant.ca/api/v1/get"

# Group Name in FSRM #
$fileGroupName = "ALTAE_CryptoBlocker_extensions"
$fileTemplateName = "ALTAE_TemplateBlocker_Crypto"
$fileScreenName = "ALTAE_FiltreBlocker_Crypto"

# Define if you want to keep passive protection shares.
# Passive protection shares allow writing forbidden extension but generate an event log
# So FSRM do not protect passive protection Shares
# Set it to 1 or another value different than 0 will cause de script to delete Passive Shares generated by this script from FSRM
$delpassive = "0"
#############################################

# First test that extensions.old is present and not empty ans online extensions list is reachable
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
Try
{
# Verifying if new crypto extensions available #
Invoke-WebRequest $url -OutFile $wkdir\extensions.txt -UseBasicParsing

$dif = compare-object -referenceobject $(get-content "$wkdir\extensions.txt") -differenceobject $(get-content "$wkdir\extensions.old")

if (!$dif) { 

Write-Host "No new extensions to apply - Quit"

rm $wkdir\extensions.txt
exit 
}
}
Catch
{

Write-Host "Remote extension list Offline - Quit"

If (Test-Path "$wkdir\extensions.txt")
{rm $wkdir\extensions.txt}

else
{
exit 
}
}

Write-Host New Crypto extensions available will be added to FSRM


# Listing all shared drives#
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -match  '0|2147483648' } | Select -ExpandProperty Path | Select -Unique

# Excluding shares present in share_to_accept.txt

$exclShares= Get-Content $wkdir\share_to_accept.txt | ForEach-Object { $_.Trim() } | Where-Object {$_ -notlike "#*"}
$monitoredShares = $drivesContainingShares | Where-Object { $exclShares -notcontains $_ }
if (!$exclShares) {

Write-Host "Shares bypassing filtering is empty"

}
else {

Write-Host "Shares bypassing filtering : $exclShares"

}


# Command to be lunch in case of violation of Anticrypto FSRM rules #
# defdault rule is non but You can use this one by adding 
# $Command to the notification in the Template
# This command stop lanmaserver to stop all shares
# To restart the service use the comman "net start lanmanserver"
$Commande = New-FsrmAction -Type Command -Command "c:\Windows\System32\cmd.exe" -CommandParameters "/c net stop lanmanserver /y" -SecurityLevel LocalSystem -KillTimeOut 0

###################################################################################################
   
# Fonction to convert the extensions list #
# in a compatible FSRM format             #                       

function ConvertFrom-Json20([Object] $obj)
{
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return ,$serializer.DeserializeObject($obj)
}

Try
{
$jsonStr = Invoke-WebRequest -Uri $url -UseBasicParsing
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })
}
Catch
{

Write-Host Error parsing extension list - Quit

rm $wkdir\extensions.txt
exit
}

# excluding from the filtered extension list ext_to_accept.txt

$exclExtensions= Get-Content $wkdir\ext_to_accept.txt | ForEach-Object { $_.Trim() } | Where-Object {$_ -notlike "#*"}
$monitoredExtensions = $monitoredExtensions | Where-Object { $exclExtensions -notcontains $_ }
if (!$exclExtensions) {

Write-Host "Extensions bypassing filtering is empty"

}
else {

Write-Host "Extensions bypassing filtering : $exclExtensions"

}


# Destination mail adress Modify if You use mail notification
# in the case of Mail Notification check your SMTP setting in the FSRM Options
$maildestination = "XXXXXX@XXX.XX"

$MailNotification = New-FsrmAction -Type Email -MailTo "$maildestination" -Subject "Cryptolocker Alert" -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60 
###############################################

$EventNotification = New-FsrmAction -Type Event -EventType Warning -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60

# Removing FSRM File Screens if allready exist
$delFSRMShares= Get-FsrmFileScreen | Select Template, Path | Where-Object {$_.Template -like "$fileTemplateName"} | Select -ExpandProperty Path
foreach ($Path in $delFSRMShares) {
Remove-FsrmFileScreen $Path -Confirm:$False

Write-Host FSRM Share "$Path" using file Screen Template "$fileTemplateName" Deleted
}

# Removing FSRM File Screen Template if Allready Exist
$delScreentemplate= Get-FsrmFileScreenTemplate | Select Name | Where-Object {$_.Name -like "$fileTemplateName"} | Select -ExpandProperty Name
foreach ($Name in $delScreenTemplate) {
Remove-FsrmFileScreenTemplate $Name -Confirm:$False

Write-Host FSRM Screen Template  $Name using File Group Name $fileGroupName Deleted
}

# Removing File Group if allready exist
$delFSRMGroupName= Get-FsrmFileGroup | Select Name | Where-Object {$_.Name -like "$fileGroupName"} | Select -ExpandProperty Name
foreach ($Name in $delFSRMGroupName) {
Remove-FsrmFileGroup $Name -Confirm:$False

Write-Host FSRM File group  $Name  Deleted

}
# Creating FSRM File Group#

Write-Host Creating FSRM File Group $fileGroupName

New-FsrmFileGroup -Name "$fileGroupName" -IncludePattern $monitoredExtensions

# Creating FSRM File Template #
# You Can modify the Notification to add the command to execute in case of violation
#    -Notification $EventNotification,$commande    that will add $Commande to be started

Write-Host Creating FSRM File Template $fileTemplateName including $fileGroupName
New-FsrmFileScreenTemplate -Name "$fileTemplateName" -Active:$True -IncludeGroup "$fileGroupName" -Notification $EventNotification

# Creating FSRM File Screen #
foreach ($share in $monitoredShares) {
New-FsrmFileScreen -Path $share -Active:$true -Description "$fileScreenName" -IncludeGroup "$filegroupname" -Template "$fileTemplateName"

Write-Host Share File Screen $share based on $fileTemplateName for the extensions list group $fileGroupName has been created

}

# Deleting Passive Protection Shares if needed

if ($delpassive -ne '0') {
$delpassiveshares= Get-FsrmFileScreen | Select Active, Path, Template | Where-Object { ($_.active -like 'False') -and ($_.Template -like "$fileTemplateName")} | Select -ExpandProperty Path
foreach ($Path in $delpassiveshares) {
Remove-FsrmFileScreen $Path -Confirm:$False
Write-Host FSRM Deleting Passive Protection Share::: $path

}
}
else {

Write-host FSRM Keeping Passive Protection Shares

}
# Keeping list to compare next #
#time with new one 
rm $wkdir\extensions.old
cp $wkdir\extensions.txt $wkdir\extensions.old
rm $wkdir\extensions.txt
Write-Host "`n"
echo Finish

Exit 
