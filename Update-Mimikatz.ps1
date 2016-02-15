function Update-Mimikatz
{
<#
 .SYNOPSIS

 This script updates the Invoke-Mimikatz.ps1 file with the lateset version of the compiled powerkatz dll files.  New dll and batteries not included. Assessories sold seperately. Void where prohibited.
 This is an adaptation of the original update-mimikatz bash script.  
 Update-Mimikatz.ps1
 Author: GraphX
 Created 2/14/2016

 .DESCRIPTION
   Update-Mimikatz.ps1 is a powershell port of the Update-Mimikatz.sh bash script I wrote. It takes the 64bit and 32bit versions of the powerkatz.dll files 
   Converts them to base64 strings and then replaces the old base64 with the new in the Invoke-Mimikatz.ps1 powershell script.  Looking back I shoudl have probably 
   Done this the first time in Powershell instead of bash.  Better late than never. Happy hacking!

 .PARAMETER
  
  -ps1 Invoke-Mimikatz.ps1 file*
  -x64 64bit powerkatz.dll file*
  -x32 32bit powerkatz.dll file*

  *denotes a reqired parameter

 #### Just remember, you're only hurting yourself if you enter in bad data. ####
 NOTE: ALL PARAMETERS ARE REQUIRED OR THE SCRIPT WILL FAIL

 .EXAMPLE
 Update-Mimikatz.ps1 -ps1 c:\pshell_scripts\invoke-mimikatz.ps1 -x64 c:\users\Admin\Documents\Mimikatz\Powerkatz_x64.dll -x32 c:\users\Admin\Documents\Mimikatz\Powerkatz_32bit.dll

 .NOTES
 Twitter: @GraphX
 Github, where I store this and other use(less||ful) factoids and half started projects that may or may not beome half finished in the next 5 years.
 Github: http://Github.com/Graph-X/

#>

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True)]
[string]$ps1,

[Parameter(Mandatory=$True)]
[string]$x64,

[Parameter(Mandatory=$True)]
[string]$x32
)
    #Check to make sure we have invoke-mimikatz.ps1 and best guess if these are correct DLL files
    #We can only go by file extension so if this passes but the process ultimately fails, this could still be wrong
    #Just a word of warning.  Make sure you are putting the right things in the right places.
    function check_inputs
    {
    if ( Test-Path $ps1 )
    {
        $ss = Select-String '\$PEBytes64 = ' $ps1
        if ( $ss -ne " " ) 
        {
            #Powershell script is good
            Write-Host "[+] We appear to have a valid Invoke-Mimikatz powershell script." -ForegroundColor Green
            Write-Verbose "[!] Search results from file prodided: $ss "
        }
        Else
        {
            #Powershell script is bad
            Write-Host "[-] This does not appear to be a valid Invoke-Mimikatz powershell script." -ForegroundColor Red
            Write-Verbose "[!] Search results from file provided: $ss "
            return $false
        }
        for($i=0; $i -le 1; $i++)
        {
            if ( $i -eq 0 ) { $dll = $x64 }
            if ( $i -eq 1 ) { $dll = $x32 }
            #Best guess checking on the DLL files
            if ( Test-Path $dll )
            {
                #file exists, but does it contain a .dll extension?
                # Get filename extension
                $extension = [System.IO.Path]::GetExtension($dll)
                "GetExtension('{0}') returns '{1}'" -f $dll, $extension
                if ( $extension = ".dll" ) 
                {
                    Write-Host "[+] $dll appears to be a dll file" -ForegroundColor Green
                    Write-Verbose "[*] This script has no real way of knowing what you fed it so it's on you if this breaks"
                }
                Else 
                {
                    Write-Host "[-] $dll does not appear to be a valid dll file" -ForegroundColor Red
                    Write-Verbose "[*] You need to make sure the extension is .dll or the script won't take it"
                    return $false
                }
            }
        }
    }
    Else { 
        Write-Host "[-] cannot find: $ps1" -ForegroundColor Red 
        return $false
    }
    return $true
    }
    #find old base64 mimikatz in the file and get md5sum for error checking
    #Using a for loop so we can get 32 and 64 bit dlls without code duplication
    function katz_md5
    {
        #setup encoding and crypto
        $utf8 = new-object -TypeName System.Text.UTF8Encoding
        $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        for ($i=0;$i -le 1;$i++)
        {
            #i=0 for 32 bit i=1 for 64bit
            #Using this scheme throughout the script helps keep things organized
            if ( $i -eq 0 ) { $bytesvar = '32' }
            if ( $i -eq 1 ) { $bytesvar = '64' }
            $oldhashline = ((get-content $ps1 | sls '\$PEBytes$bytesvar = "'))
            $oldhash = $oldhashline -split '"'
            #collect the old base64 string and the md5sum and create global variables for them.  We'll compare this later
            new-variable -Name "oldhash$bytesvar" -Value $oldhash[1] -Scope Global
            Write-Verbose "[*] base64 string for old mimikatz collected too long to display (unless you really want to see it then uncomment the line below this one."
            #Get-Variable -Name "oldhash$bytevar" -ValueOnly
            new-variable -Name "oldmd5$bytesvar" -Value ([System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes( (Get-Variable -Name "oldhash$bytesvar" -ValueOnly))))) -Scope Global
            Write-Verbose "[*] m5sum of the x$bytevar base64 string is: " + (Get-Variable -Name "oldmd5$bytevar" -ValueOnly)
            ####Encode and get the MD5 sums from the new dll files#######
            if ( $i -eq 0 ) { $dllfile = $x32 }
            if ( $i -eq 1 ) { $dllfile = $x64 }
            #first we base64 encode the files
            #stolen from: http://powershellscripts.blogspot.com/2007/02/base64-encode-file.html
            $fileContent = get-content $dllfile
            $fileContentBytes = [System.text.Encoding]::UTF8.GetBytes($fileContent)
            new-variable -Name "newdll$bytesvar" -value ([system.convert]::ToBase64String($fileContentBytes)) -Scope Global
            new-variable -Name "newmd5sum$bytesvar" -value ([System.BitConverter]::ToString($md5.ComputeHash($fileContentBytes))) -Scope global
        }
    }

    #backup the old ps1 just in case we break it doing the update
    function backup
    {
        Write-Host "[*] Checking for $ps1..."
        if ( Test-Path $ps1 )
        {
            Write-Host "[*] $ps1 exists. Making backup"
            $FilePath = Split-Path $ps1
            if (!($FilePath = $null)) 
            { 
                $imFileName = Split-Path $ps1 -Leaf
            }
            Else 
            { 
                $imFileName = $ps1
            }
            $backupFile = $imFileName -replace '\.([a-z]|[A-Z]|[0-9])*$', ".bak"
            #Check for working directory and move there if we haven't already
            if ( ($FilePath -ne $null) -and ($pwd.Path -ne $FilePath) ) { Set-Location -Path $FilePath }

            if (!(Test-Path $backupFile))
            {
                copy $imFileName $backupFile
                if ( Test-Path $backupFile )
                {
                    Write-Host "[+] $backupFile has been made" -ForegroundColor Green
                    return true
                }
                Else { Write-Host "[-] $backupfile was not made. Aborting update. Make sure file can be written to $FilePath" -ForegroundColor Red; return false }
            }
            Else { Write-Host "[*] $backupFile already exists. Moving on."; return true }
        }
        Else { Write-Host "[-] could not find $ps1.  Please make sure it is correct and try again" -ForegroundColor Red; return false}
    }
    Function replace_mkatz
    {
        #real simple find and replace. Like sed only more funky syntax
        Write-Verbose "[*] replacing the base64 encoded strings"
        cat $ps1 | %{$_-replace "$oldhash32","$newdll32"}
        $newhashline = ((Get-Content $ps1 | sls '\$PEBytes32 = "'))
        $newhash = $newhashline -split '"'
        $newhash = $newhash[1]
        $new32md5 = ([System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($newhash))))
        cat $ps1 | %{$_-replace "$oldhash64","$newdll64"}
        $newhashline = ((Get-Content $ps1 | sls '\$PEBytes64 = "'))
        $newhash = $newhashline -split '"'
        $newhash = $newhash[1]
        $new64md5 = ([System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($newhash))))
        #now we check the md5sum against of the base64 in the Invoke-Mimikatz.ps1 file against the sum we got when we encoded the new powerkatz dll files.
        if ( $new32md5 -eq $newmd5sum32 )
        {
            Write-Host "[+] md5sums match for 32bit dll" -ForegroundColor Green
            Write-Verbose "[*] Old sum: $odlmd532"
            write-verbose "[*] New sum1: $newmd5sum32"
            Write-Verbose "[*] New sum2: $new32md5"
        }
        else
        {
            Write-Host "[+] md5sums do not match 32bit dll" -ForegroundColor Red
            Write-Verbose "[*] Old sum: $odlmd532"
            write-verbose "[*] New sum1: $newmd5sum32"
            Write-Verbose "[*] New sum2: $new32md5"
            return $false
        }
        if ( $new64md5 -eq $newmd5sum64 )
        {
            Write-Host "[+] md5sums match for 64bit dll" -ForegroundColor Green
            Write-Verbose "[*] Old sum: $oldmd564"
            write-verbose "[*] New sum1: $newmd5sum64"
            Write-Verbose "[*] New sum2: $new64md5"
        }
        else
        {
            Write-Host "[+] md5sums do not match 64bit dll" -ForegroundColor Red
            Write-Verbose "[*] Old sum: $odlmd564"
            write-verbose "[*] New sum1: $newmd5sum64"
            Write-Verbose "[*] New sum2: $new64md5"
            return $false
        }
        return $true
    }
#########################
#                       #  
#     Main section      #
#                       #
#########################
#Order of events:
#1. check our variables
#2. backup
#3. record md5sum  from old hashes and collect them
#4. convert new dll files to base64 and replace the old 
#5. compare md5sums
#6. rejoice if shit didn't break  

    #inputs good?  Otherwise black hole
    if ( check_inputs -ne $false ) 
        {
            if ( backup -ne $false )
            {
                write-host "[+[ almost done.  Things look good so far no let's actaully do something"
                Write-Verbose "[*] Getting md5sums"
                katz_md5
                write-host "[+] Updating $ps1 with the new dll files now"
                if ( replace_mkatz -ne $false) { write-host "[+] Invoke-Mimikatz updated. Happy Hacking!" }
            }
        }
}
