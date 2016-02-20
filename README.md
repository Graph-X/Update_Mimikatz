# Update_Mimikatz
Update-Mimikatz is an effort in efficiency.  Currently it consists of two files that (should) do the exact same thing: Upate the Invoke-Mimikatz.ps1 with new versions of the powerkatz dll files.

Update-Mimikatz.sh is a bash script that takes the compiled dll files converts them to base64 strings and then replaces the old dll base64 strings with the new ones.  

Update-Mimikatz.ps1 is an untested powershell port of the bash script. In theory everything should work the same, but I haven't debugged it yet.  If you absolutely need it to work, you might not want to start with this one.

