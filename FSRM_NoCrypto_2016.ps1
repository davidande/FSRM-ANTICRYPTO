﻿##############################
# FSRM_ALTAE_2016.ps1        #
# David ANDE - ALTAE         #
# WWW.ALTAE.NET              #
# GNU GENERAL PUBLIC LICENSE #
##############################

# Using FSRM to Block users writing file with a forbiden extension.
# This scripts can be add as a task to check newer version of extensions list : program: c:\windows\system32\windowsPowerShell\v1.0\Powershell.exe
# Arguments to add: -noprofile  -executionpolicy Unrestricted -file "where is this script" default c:\FSRMANTICRYPTO\FSRM_ALTAE_AntiCrypto.ps1
# Before using this script, You have to install FSRM
# Add Role -> File Services/File Server Ressource Manager
# Alternative install can be done with the command: Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
# Lunch FSRM.MSC and Right Click on File Server Ressource Manager to configure Mail notification Settings
# SMTP Server, Default destination mail and sender adress
# Click on Send a test mail to check settings working and validate

###############################################
# VARIABLES TO EDIT BEFORE USE #
# Working directory
$wkdir = "C:\FSRMNOCRYPTO"

# Group Name in FSRM #
$fileGroupName = "ALTAE_CryptoBlocker_extensions"
$fileTemplateName = "ALTAE_TemplateBlocker_Crypto"
$fileScreenName = "ALTAE_FiltreBlocker_Crypto"
#############################################

# Verifying if new crypto extensions available #
Invoke-WebRequest https://fsrm.experiant.ca/api/v1/get -OutFile $wkdir\extensions.txt

$taille1 = Get-FileHash $wkdir\extensions.txt
$taille2 = Get-FileHash $wkdir\extensions.old
if ($taille1.Hash -eq $Taille2.Hash) {
    Write-Host No New Crypto Extensions available
    rm $wkdir\extensions.txt
    Exit
}
Write-Host New Crypto extensions available will be added to FSRM

# Listing all shared drives#
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -match  '0|2147483648' } | Select -ExpandProperty Path | Select -Unique
# $drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -eq 0 } | Select -ExpandProperty Path | % { "$((Get-Item -ErrorAction SilentlyContinue $_).Root)" } | Select -Unique
Write-Host "Drives to be protected: $($drivesContainingShares -Join ",")"

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
############################################### SCRIPT ##############################
$webClient = New-Object System.Net.WebClient
$jsonStr = $webClient.DownloadString("https://fsrm.experiant.ca/api/v1/get")
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })

# Destination mail adress Modify if You use mail notification
# in the case of Mail Notification check your SMTP setting in the FSRM Options
$maildestination = "XXXXXX@XXX.XX"

$MailNotification = New-FsrmAction -Type Email -MailTo "$maildestination" -Subject "Cryptolocker Alert" -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60 
###############################################

$EventNotification = New-FsrmAction -Type Event -EventType Warning -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60


# Creating FSRM File Group#
Remove-FsrmFileGroup -Name "$fileGroupName" -Confirm:$false
Write-Host Creating File Group $fileGroupName
New-FsrmFileGroup -Name "$fileGroupName" –IncludePattern $monitoredExtensions

# Creating FSRM File Template #
# You Can modify the Notification to add the command to execute in case of violation
#    -Notification $EventNotification,$commande    that will add $Commande to be started
Remove-FsrmFileScreenTemplate -Name "$fileTemplateName" -Confirm:$false
Write-Host Creating File Template $fileTemplateName including $fileGroupName
New-FsrmFileScreenTemplate -Name "$fileTemplateName" -Active:$True -IncludeGroup "$fileGroupName" -Notification $EventNotification

# Creating FSRM File Screen #
foreach ($share in $drivesContainingShares) {
Remove-FsrmFileScreen $share -Confirm:$false
}
Write-Host Creating File Screen $fileScreenName based on $fileTemplateName for the extensions list group $fileGroupName on drives $drivesContainingShares
foreach ($share in $drivesContainingShares) {
New-FsrmFileScreen -Path $share -Active:$true -Description "$fileScreenName" –IncludeGroup "$filegroupname" –Template "$fileTemplateName"
}
rm $wkdir\extensions.old
cp $wkdir\extensions.txt $wkdir\extensions.old
rm $wkdir\extensions.txt
Exit