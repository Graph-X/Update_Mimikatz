#!/bin/bash
#
# Update Mimikatz
# Created 1-12-16 by @GraphX
# Last Updated: 1-21-2016
# Description:
#	The script will take your 32 bit and 64 bit 
#	Powerkatz dll files, encode them to b64 and
#	update the Invoke-Mimikatz.ps1 file
###################################################
set -e
ESC_SEQ="\033["
COL_RESET=$ESC_SEQ"0m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
#Attempt to backup the powershell script in the event that I break it
backup() {

#Get just the filename and not the extension
FILENAME=`echo $MKATZ_FILE`.bak
#does the powershell script exist and have we already made a backup?
if [[ -e $MKATZ_FILE && ! -e $FILENAME ]]; then

#make a backup since we haven't already
        cp $MKATZ_FILE $FILENAME 
	echo -e "[*] Backing up file saved to $FILENAME" 
	return 0
fi
#No powershell no washey  Either typo or can't follow directions
if [[ ! -e $MKATZ_FILE ]]; then
        echo -e "$COL_RED[-] Could not find powershell script. please make sure it's correct in the command line.$COL_RESET"
        return 1
fi
#Do we already have a backup?
if [[ -e $FILENAME ]]; then
	#We don't make another backup because of the potential to overwrite a good backup with garbage
        echo -e "[*] Looks like a backup has already been made. moving on"
		return 0
fi
}


#This is the meat and potatoes of the script
update() {
#Here we grab just the base64 strings and line number in an array from the ps1 for each arch
#This part was a pain in the ass to write so I hope this is appreciated.
#lessons learned while slaving away on this:
#The base64 strings are too large to be handled with sed as a normal variable.
#What I had to do was stream the file contents and then redirect the stdout to an awk session using heredoc. 

#Trust but verify.  Do we have the correct files?
if [[ -e $MKATZ_FILE ]]; then
	if  [ $(grep -c 'PEBytes64 = \"' $MKATZ_FILE) -ne 0 ]; then
		#Looks like a valid invoke PE script. Fuck it, let's fly!
		
		#Were we given valid DLLs? Use file mime-type for best guess
		if  [[ $(file --mime-type $PKATZ64 | rev | cut -d ' ' -f 1 | rev) == application/x-dosexec  &&  $(file --mime-type $PKATZ32 | rev | cut -d ' ' -f 1 | rev) == application/x-dosexec ]]; then
			#both the dll files match their expected mime types.  We can proceed
			echo -e "$COL_GREEN[+] $PKATZ64 and $PKATZ32 appear to be the proper file type.$COL_RESET"
		else
			echo -e "$COL_RED[-] Unable to process given files. Please check spelling and proper file type and try again.$COL_RESET"; exit 1 
		fi
	else
		echo -e "$COL_RED[-] Unable to validate $MKATZ_FILE as a proper PE reflection script. Please try again.$COL_RESET"; exit 1
	fi
else
	echo -e "$COL_RED[-] Unable to find $MKATZ_FILE. Please verify the location and try again $COL_RESET"; exit 1
fi	
		
		

#
#We use two for loops to run through both ARCHs here
#THIS IS WHERE THE NEW INFORMATION GETS POPULATED FROM THE DLLS AND ADDED TO THE POWERSHELL FILE
#


#The if statement could likely be shortened, but for right now it works as is.
for a in $(seq 0 1); do
	if [ $a == 0 ]; then
		echo -e "[*] Updating the 64 bit library"
		ARCH=""
		ARCH="64"
		PKATZ="$PKATZ64"
		LINE[$a]=`grep -n "PEBytes64 = \"" $MKATZ_FILE | cut -d ':' -f 1`
		OLDKATZ[$a]=`grep "PEBytes64 = \"" $MKATZ_FILE | cut -d ':' -f 1 | tr -d '"'`
	else
		echo -e "[*] Updating the 32 bit library"
		PKATZ="$PKATZ32"
		ARCH=""
		ARCH="32"
		OLDKATZ[$a]=`grep "PEBytes32 = \"" $MKATZ_FILE | cut -d ':' -f 1 | tr -d '"'`
		LINE[$a]=`grep -n "PEBytes32 = \"" $MKATZ_FILE | cut -d ':' -f -1`
	fi
############################################################################
#
#This section is where the base64 strings created from the DLL files are added to the powershell
#the OUTPUT variable holds the base64 encoding the 64bit payload and then 32.
#md5sums are created to ensure consistency and verifiable source. This feature will be 
#added in the future.  Right now it's good for error checking though.
#
#As it just so happens, we cannot just stuff the new file in to the powershell script. The base64 string
#is waaaaay too long.  Therefore we will read 1024 charcters at a time.
#######################################################################################################
		
	#OUTPUT will be the stream variable that we pipe back to the while loop
	OUTPUT=`base64 -w 0 $PKATZ`
	
	#get md5sum for error checking
	NEWMD5=`md5sum <<< $OUTPUT`
	NEWMD5=`echo $NEWMD5 | cut -d ' ' -f 1`
	
	#Token to mark beginning of the file 
	w=0;

	#while loop to stream $OUTPUT from the base64 conversion of the powerkatz.dll file
	#Awk sucks but I couldn't stream the string through sed because it exceeds the kernel's ARG_MAX value
	while read -r -n 1024 char; do
		if [[ $w == 0 ]]; then
			w=1
			awk -i inplace 'BEGIN{FS=OFS="\""} {if (NR == "'${LINE[$a]}'")  {$2="'$char'"} print $0;}' $MKATZ_FILE
		else
			awk -i inplace 'BEGIN{FS=OFS="\""} {if (NR == "'${LINE[$a]}'") {$2=$2"'$char'"} print $0;}' $MKATZ_FILE
		fi	
		done <<< $OUTPUT

	#grab the base64 string from the mimikatz file.  It should be different now.
	NEWHASH=`grep "PEBytes$ARCH = \"" $MKATZ_FILE | cut -d '"' -f 2 | tr -d '"'`
	#Get the md5sum of base64 string now in the powershell
	NEWSUM=`md5sum <<< $NEWHASH`
	NEWSUM=`echo $NEWSUM | cut -d ' ' -f 1`
	#md5sum checking 
	echo -e "[*] MD5 of the base64 string for x$ARCH in the $MKATZ_FILE is $NEWSUM"
	echo -e "[*] The new md5 of base64 string from the powerkatz dll is $NEWMD5"
	if [[ $NEWSUM !=  $NEWMD5 ]]; then 
		echo -e  "$COL_RED[-]***MD5sums Do NOT Match***$COL_RESET" | read -p " "
		#echo "NEWSUM content length is ${#NEWSUM}" > ./error
		#echo "NEWMD5 content length is ${#NEWMD5}" >> ./error 
		echo -e "$COL_RED[-] Something went wrong with the upgrade\n$COL_RESET"
		cp $FILENAME $MKATZ_FILE 
		x=1 #shit's not right.  These sums should match
	else
		echo -e "$COL_GREEN[+] Library for "$ARCH"bit Mimikatz passed MD5 check$COL_RESET"
	fi

done
if [ $x == 0 ]; then 
	return 0 
else
	return 1
fi	
}

#just making things pretty
#usage menu:
show_parms() {
		echo -e "\n\n$COL_BLUE\tRTFM for Update-Mimimkatz.sh$COL_RESET\n"
		printf "\t Usage: $0 [args] \n\n"
		printf "\t-ps1  > Invoke-Mimikatz.ps1 file\n"
		printf "\t-x64  > powerkatz_x64.dll file\n"
		printf "\t-x32  > powerkatz_32bit.dll file \n"
		printf "Command example:\n"
		printf "#$0 -ps1 ./Invoke-Mimikatz.ps1 -x64 ./powerkatz_x64.dll -x32 ./powerkatz_x32.dll\n\n\n"
}

##########################################
#main subroutine
x=0
#If we don't have everything submitted, then RTFM
if [ $# -lt 6 ]
then
	show_parms
        exit
fi

VARS=`echo "$*" | sed 's/ [^ ]*$//'`
while [ $# -gt 1 ] ; do
        
	case $1 in
	-ps1|--ps1)
		#move to the next in line
		shift
		MKATZ_FILE="$1"
		;;
	-x64|--x64)
		#move to next in line
		shift
		PKATZ64="$1"
		;;
	-x32|--x32)
		#move to next in line
		shift
		PKATZ32="$1"
		;;
	*)
		show_parms
		exit 1
		;;
	esac
	shift
done

if backup = 0; then
	echo -e  "$COL_GREEN[+] Proceeding with the update...$COL_RESET"
	if update = 0; then
		echo -e "$COL_BLUE[!] Script completed successfully.  Happy Hacking!$COL_RESET"
		exit 0
	else
		show_parms
		echo -e "$COL_RED[-]Something went wrong with the update. Try again later.$COL_RESET"
		exit 1
	fi
else 	
	show_parms
	echo -e "$COL_RED[-]Unable to backup the script.  Cannot continue until we have a backup.$COL_RESET"
	exit 1
fi
echo -e "$COL_RED[!!]There's no way we should be here.  You must be a wizard Harry!$COL_RESET"
exit 1337

