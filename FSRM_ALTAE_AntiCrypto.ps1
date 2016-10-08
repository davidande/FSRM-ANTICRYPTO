#############################
# FSRM_ALTAE_AntiCrypto.ps1 #
# David ANDE - ALTAE        #
# WWW.ALTAE.NET             #
# 07/10/2016                #
#  V1.0                     #
#############################

# Le principe est d'utiliser une liste d'extensions crypto mise à jour par la communauté en temps réel
# et de configurer le service FSRM de manière à interdire l'écriture de fichiers contenant ces extensions.
# Par défaut si une violation est constatée, un mail est envoyé à l'administrateur
# et le service de partage est stoppé.
# le script doit être planifié pour se mettre à jour toutes les heures pour plus de sécurité.
# testé sous: w2012, w2012R2 et w2016

###############################################
# VARIABLES TO EDIT BEFORE USE #
# Working directory
$wkdir = "C:\FSRM"
#Distination mail adress #
$maildestination = "david.ande@wanadoo.fr"
###############################################
# Group Name in FSRMFSRM #
$fileGroupName = "ALTAE_Crypto_extensions"
$fileTemplateName = "ALTAE_Modele_Filtrage_Crypto"
$fileScreenName = "ALTAE_Filtre_Crypto"
#############################################

# Verifying if new crypto extensions available #
Invoke-WebRequest https://fsrm.experiant.ca/api/v1/get -OutFile $wkdir\extensions.txt
$taille1 = Get-FileHash $wkdir\extensions.txt
$taille2 = Get-FileHash $wkdir\extensions.old
if ($taille1.Hash -eq $Taille2.Hash) {
    rm extensions.txt
    Write-Host No New Crypto Extensions available
    Exit
}
Write-Host New Crypto extensions available will be added to FSRM

# Listing all shared drives#
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -eq 0 } | Select -ExpandProperty Path | % { "$((Get-Item -ErrorAction SilentlyContinue $_).Root)" } | Select -Unique

Write-Host "Shared drives to be protected: $($drivesContainingShares -Join ",")"

# Command to be lunch in case of violation of Anticrypto FSRM rules #
# defdault rule stop lanmaserver to stop all shares
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
$Notification = New-FsrmAction -Type Email -MailTo "$maildestination" -Subject "Cryptolocker Alert" -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60 



# Creating FSRM File Group#
Remove-FsrmFileGroup -Name "$fileGroupName" -Confirm:$false
Write-Host Creating File Group $fileGroupName
New-FsrmFileGroup -Name "$fileGroupName" –IncludePattern $monitoredExtensions

# Creating FSRM File Template #
Remove-FsrmFileScreenTemplate -Name "$fileTemplateName" -Confirm:$false
Write-Host Creating File Template $fileTemplateName including $fileGroupName
New-FsrmFileScreenTemplate -Name "$fileTemplateName" -Active:$True -IncludeGroup "$fileGroupName" -Notification $Notification,$commande

# Creating FSRM File Screen #
foreach ($share in $drivesContainingShares) {
Remove-FsrmFileScreen $share -Confirm:$false
}
Write-Host Creating File Screen $fileScreenName based on $fileTemplateName for the extensions list group $fileGroupName on drive(s) $drivesContainingShares
foreach ($share in $drivesContainingShares) {
New-FsrmFileScreen -Path $share -Active:$true -Description "$fileScreenName" –IncludeGroup "$filegroupname" –Template "$fileTemplateName"
}
rm $wkdir\extensions.old
cp $wkdir\extensions.txt $wkdir\extensions.old
rm $wkdir\extensions.txt
exit
