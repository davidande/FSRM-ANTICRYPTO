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


# VARIABLES #

#Adresses mails #
$maildestination = "administrator_mail"

# Ajouter tous les volumes avec partages#
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -eq 0 } | Select -ExpandProperty Path | % { "$((Get-Item -ErrorAction SilentlyContinue $_).Root)" } | Select -Unique

Write-Host "Protection sur ces lecteurs: $($drivesContainingShares -Join ",")"

# Nom des differents groupes dans FSRM #
$fileGroupName = "ALTAE_Crypto_extensions"
$fileTemplateName = "ALTAE_Modele_Filtrage_Crypto"
$fileScreenName = "ALTAE_Filtre_Crypto"
#############################################

# Commande a executer en cas de violation des regles # par defaut on arrete le service de partage #
$Commande = New-FsrmAction -Type Command -Command "c:\Windows\System32\cmd.exe" -CommandParameters "/c net stop lanmanserver /y" -SecurityLevel LocalSystem -KillTimeOut 0
###################################################################################################
   
# Fonction de conversion de liste d'extensions         #
# permet de convertir la liste d'extension téléchargée #
# en un format compatible avec FSRM                    #

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
$Notification = New-FsrmAction -Type Email -MailTo "$maildestination" -Subject "Alerte Cryptolocker" -Body "l'utilisateur [Source Io Owner] tente de sauvegarder [Source File Path] en [File Screen Path] sur le serveur [Server]. Ce fichier se trouve dans le groupe [Violated File Group], qui n'est pas permis sur le serveur." -RunLimitInterval 60 


# Creation ou remplacement du groupe de fichiers #
Remove-FsrmFileGroup -Name "$fileGroupName" -Confirm:$false
New-FsrmFileGroup -Name "$fileGroupName" –IncludePattern $monitoredExtensions

# Creation ou remplacement du modele de filtre #
Remove-FsrmFileScreenTemplate -Name "$fileTemplateName" -Confirm:$false
New-FsrmFileScreenTemplate -Name "$fileTemplateName" -Active:$True -IncludeGroup "$fileGroupName" -Notification $Notification,$commande

# Creation ou remplacement des filtres de fichiers #
foreach ($share in $drivesContainingShares) {
Remove-FsrmFileScreen $share -Confirm:$false
}
foreach ($share in $drivesContainingShares) {
New-FsrmFileScreen -Path $share -Active:$true -Description "$fileScreenName" –IncludeGroup "$filegroupname" –Template "$fileTemplateName"
}
