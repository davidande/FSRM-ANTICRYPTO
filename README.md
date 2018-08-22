# FSRM-ANTICRYPTO
Protect servers against crypto attacks

Use FSRM-ANTICRYPTO to protect your Windows servers against Crypto attacks and keep the Crypto filegroup extensions up to date.
A very completelist is maintained by experiant.ca with infos gave by the community. Check-it at https://fsrm.experiant.ca.
Configuring FSRM make impossible to users to write files with forbiden extensions. So We use FSRM to avoid encrypted files to be saved as the extension used by the Crypto Process is Known.
Those scripts and howto are given as is. Use at your own risck. I will take no responsability for that.
This work is heavily based on Kinomakino and Nexxai on Github. Big hug!
Also Thanks to Jpelectron who gave me the idea to go further.
 
# So What!
- Update list of banned extensions (through task manager or manually)
- Configure extensions list, template and applying on shares
- Possibility to exclure extensions from the blocked list (false positive)
- Possibility to exclude shares (excluding some specific shares like usb dongle...) 
- Possibility to stop all shares when attack is detected
- Possibility to delete passive fsrm screen

# Installation 

First of all You need at least Powershell V3 installed
- https://blog.adsl2meg.fr/installer-powershell-3-sur-windows-server-2008-r2/ 
and check the web for other server version

Without Powershell V3 ou V4, the script will end

If You want newer version of powershell You can install 5.1
https://blog.adsl2meg.fr/installer-powershell-5-1-sur-windows-server-2008-r2-2012-ou-2012-r2/


You can check that it's works by renaming a file in a share, just change the extension for exemple test.doc -> test.tron
it will be forbiden.
You can also follw all attempts in the events log.

1- Installation of FSRM Role
Install FSRM on Yor server: Add-Role->File Service ->File Server Ressource Manager
As sometime Windows file manager is configured in Case sensitive, you have to
configure it by checking HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel obcaseinsensitive is set to 1

2- Installation of script
Download the FSRMNOCRYPTO.ZIP and UnZip only files to C:\FSRMNOCRYPTO so C:\FSRMNOCRYPTO contain:
- FSRM_NOCRYPTO_2008.ps1 -> to be used with Windows Server 2008 and 2008 R2 (and in some case 2012)
- FSRM_NOCRYPTO_2016.ps1 -> to be used with Windows Server 2012, 2012 R2, 2016 and 2019 Preview
- extensions.old -> used to compare local en remote extensions list
- ext_to_accept.txt -> is use to input all the extensions that are in the blocked list but You want to accept
- Readme.md -> this file
- Licence

3- Running the script
First check that .NET and ASP.NET are installed (check fonctionnalities)
Second check Set-ExecutionPolicy to acces execution of nonsigned scripts (bypass or remotesigned)
Start the script in a Powershell session with admin right.
First time You should see some errors. No problem it's only cause by deleting objects that are not yet created.
To check if everything is ok, just empty the extensions.old and lunch the script again. This time You should See no error

4- Drive and extension exclusion. 
As some program use certain type of extension that are known to be ine the ransomware list, You can put the list of extensions to bypass the FSRM blocking filter in the file est_to_accept.txt
For the drive extension You can exclude 2 from bloking directly in the script.

5- Task to update de file
This scripts can be add as a task to check newer version of extensions list : 
program: c:\windows\system32\windowsPowerShell\v1.0\Powershell.exe
Arguments to add: -noprofile  -executionpolicy Unrestricted -file "where is this script" default "C:\FSRMNOCRYPTO\FSRM_NOCRYPTO_20**.ps1".

The task must be launched at least twice a day

You can check that it's works by renaming a file in a share, just change the extension for exemple test.doc -> test.tron
it will be forbiden.
You can also follw all attempts in the events log.

# Sources #
https://github.com/kinomakino/ransomware_file_extensions/blob/master/anti_ransomware.ps1

https://fsrm.experiant.ca/

http://jpelectron.com/sample/Info%20and%20Documents/Stop%20crypto%20badware%20before%20it%20ruins%20your%20day/1-PreventCrypto-Readme.htm

# IF ERRORS!!! #
post an issue, I should know some way to make it work fot You

1- make sure to launch Internet Explorer one time on the server and choose parameters when asked (default works)
2- if you just installed FSRM role, reboot the server
