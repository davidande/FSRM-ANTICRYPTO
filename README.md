# FSRM-ANTICRYPTO
Protect servers against crypto attacks

use FSRM-ANTICRYPTO to protect your Windows servers against Crypto attacks and keep the Crypto filegroup extensions up to date

# Howto Use #
1-Install FSRM on Yor server: Add-Role->File Service ->File Server Ressource Manager
As sometime Windows file manager is configured in Case sensitive, you have to
configure it by checking HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel obcaseinsensitive is set to 1

2-Download the FSRMANTICRYPTO.ZIP and UnZip it to C:\
C:\FSRMANTICRYPTO contain
- FSRM_ALTAE_2008.ps1 -> to be used with Windows Server 2008 and 2008 R2
- FSRM_ALTAE_2016.ps1 -> to be used with Windows Server 2012, 2012 R2 and 2016
- extensions.old -> used by FSRM_ALTAE_2016.ps1 to compare local en remote extensions list
- Readme.md -> this file

3- Task to update de file
This scripts can be add as a task to check newer version of extensions list : 
program: c:\windows\system32\windowsPowerShell\v1.0\Powershell.exe
Arguments to add: -noprofile  -executionpolicy Unrestricted -file "where is this script" default C:\FSRMANTICRYPTO\FSRM_ALTAE_20**.ps1 

# Sources #
https://github.com/kinomakino/ransomware_file_extensions/blob/master/anti_ransomware.ps1

https://fsrm.experiant.ca/

http://jpelectron.com/sample/Info%20and%20Documents/Stop%20crypto%20badware%20before%20it%20ruins%20your%20day/1-PreventCrypto-Readme.htm

