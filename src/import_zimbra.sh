#!/bin/bash
#
# Written by Hodfords.com Ltd (https://www.hodfords.com/)
# Released under GNU General Public License v3 (GPL-3)
#
# This script is free for anyone to use and can be distributed freely 
#
# You are solely responsible for adequate protection and backup of the data and equipment used in connection with any of this script, and we will not be liable for any damages that you may suffer connection with downloading, installing, using, modifying or distributing such script.
## To be run on the source server (the server that you are migrating away from)
#
# The script assumes that you have made backups using export_zimbra.sh on the source server (the one that you are trying to migrate from) and that you are on Zimbra 8.8.15 - it may work for other versions but not tested yet 
# Assumes that you have root access to the source server too. First the script will use rsync to transfer the files.  
#
# The default backup directory is /opt/zmbackup and assumes that the directory on the source server is the same
# 
## Tested running Zimbra 8.8.15 
## Script Name : import_zimbra.sh
## 
## Recommended location : /opt/scripts/import_zimbra.sh
## Remember to make the script executable by running: chmod 755 /opt/scripts/import_zimbra.sh
BACKUP_DIR="/opt/zmbackup"
#Preferences that will be imported - add or delete as you see fit 
IMPORT_PREF=("zimbraPrefLocale" "zimbraPrefConversationOrder" "zimbraPrefDefaultPrintFontSize" "zimbraPrefDisplayExternalImages" "zimbraPrefFolderTreeOpen" "zimbraPrefHtmlEditorDefaultFontColor" "zimbraPrefHtmlEditorDefaultFontFamily" "zimbraPrefHtmlEditorDefaultFontSize" "zimbraPrefComposeInNewWindow" "zimbraPrefGroupMailBy" "zimbraPrefHtmlEditorDefaultFontColor" "zimbraPrefHtmlEditorDefaultFontSize" "zimbraPrefFromAddress" "zimbraPrefFromDisplay" "zimbraPrefGalAutoCompleteEnabled" "zimbraPrefComposeFormat" "zimbraPrefCalendarViewTimeInterval" "zimbraPrefCalendarReminderDuration1" "zimbraPrefCalendarInitialView" "zimbraPrefFolderTreeOpen" "zimbraPrefMailTrustedSenderList" "zimbraPrefMandatorySpellCheckEnabled" "zimbraPrefOutOfOfficeReplyEnabled" "zimbraPrefTimeZoneId" "zimbraPrefSkin" "zimbraPrefFont" "zimbraPrefClientType" "zimbraPrefConvReadingPaneLocation" )

echo "This script should be run as root.... Maybe exit now with Ctrl-c if not"
sleep 1

if [ -z "$1" ]
then
      echo "Usage of this script : ./import_zimbra.sh <<source server IP>> <<directory>>(optional)"
      echo "Example Use : ]# ./import_zimbra.sh 111.222.333.444 /opt/zmbackup"
      echo "Example Use : ]# ./import_zimbra.sh 111.222.333.444"
      echo ""
      echo "Hostnames can be used in lieu of IP addresses but do so with caution to make sure the IP resolution is correct"
      echo "Assumes that you have root access to the source server. Run this as root"
      echo "It is suggested that you use screen in case the connection gets broken and the import process gets disrupted."
      echo "Please make sure that imapsync is installed - otherwise the copying of emails will not work"
      exit 1
else
      echo "$1 is the source server IP address"
      SOURCE=$1
      if [ -z "$2" ]
      then
      echo "Source Server Data Directory : ${BACKUP_DIR}"
      SOURCE_DIR=${BACKUP_DIR}
      else 
      echo "Source Server Data Directory : ${2}"
      TRIMMED=${2%/}
      SOURCE_DIR=${TRIMMED}
      fi
fi
echo "--------------------------------------------------"
echo "To Confirm migration start we will be copying from"
echo "SOURCE ZIMBRA SERVER : ${SOURCE}"
echo "SOURCE ZIMBRA SERVER BACKUP DIRECTORY : ${SOURCE_DIR}"
echo ""
echo "TARGET BACKUP Server : localhost"
echo "TARGET BACKUP DIRECTORY : ${BACKUP_DIR}"
echo "--------------------------------------------------"
echo ""
echo "If the above information is correct - do you want to proceed with import (y/n)?"
  
read RESPONSE_VAR
if [ ${RESPONSE_VAR} != "y" ]
  then
  echo "exiting..."
  exit 0
fi 

## Create Backup Directory
if [ ! -d "$BACKUP_DIR" ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}..."
  mkdir ${BACKUP_DIR}
  echo "Chown zimbra:zimbra ${BACKUP_DIR}..."
  chown -R zimbra:zimbra ${BACKUP_DIR}
else
  # Directory Found
  echo "Found ${BACKUP_DIR}..."
  echo "Chown zimbra:zimbra ${BACKUP_DIR}..."
  chown -R zimbra:zimbra ${BACKUP_DIR}
fi
sleep 2

echo "Start Import Process..."
echo "--------------------------------------------------"
echo "Will run this command :"
echo "rsync -azlgop --progress root@${SOURCE}:${SOURCE_DIR}/ ${BACKUP_DIR}/"
echo ""
echo "There is a 2-second wait before this will start so you can press Ctrl-c or Ctrl-z to exit"
echo "--------------------------------------------------"
sleep 2

#Sync 
echo "Start Syncing Data from Source to Destination - you will be prompted for the root password by rsync...."
rsync -azlgop --progress root@${SOURCE}:${SOURCE_DIR}/ ${BACKUP_DIR}/
echo "Finished Syncing Data from Source to Destination...."
sleep 1

echo "Check to see if everything is there..."
if [ -e ${BACKUP_DIR}/domains.txt ]
then
    echo "${BACKUP_DIR}/domains.txt exists"
else
    echo "${BACKUP_DIR}/domains.txt does not exist"
    exit 0
fi

if [ -e ${BACKUP_DIR}/emails.txt ]
then
    echo "${BACKUP_DIR}/emails.txt exists"
else
    echo "${BACKUP_DIR}/emails.txt does not exist"
    exit 0
fi

echo "Start Import of Domains..."
for i in `cat ${BACKUP_DIR}/domains.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov cd $i zimbraAuthMech zimbra ;echo $i ;done
echo "Finished Importing Domains..."
echo "Current Domain List:"
sudo -u zimbra /opt/zimbra/bin/zmprov gad
sleep 1

echo "Do you want to import users (y/n)?"
sleep 1
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Users..."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do
  givenName=$(grep givenName: ${BACKUP_DIR}/userdata/$i.txt | cut -d ":" -f2)
  displayName=$(grep displayName: ${BACKUP_DIR}/userdata/$i.txt | cut -d ":" -f2)
  shadowpass=$(cat ${BACKUP_DIR}/userpass/$i.shadow)
  tmpPass="CHang*ksl9"
  sudo -u zimbra /opt/zimbra/bin/zmprov ca $i ${tmpPass} cn "$givenName" displayName "$displayName" givenName "$givenName"
  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i userPassword "$shadowpass"
  done
  echo "Finished Importing Domains..."
  echo "Current User List:"
  sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa
  sleep 1
fi 


echo "Do you want to import Signatures and Autoresponders (y/n)?"
sleep 1
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Signatures and Autoresponders..."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do
    #signatures
    if [ -e ${BACKUP_DIR}/signatures/$i.txt ]
    then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/signatures/$i.txt")
        if [ ${FILESIZE} -ne 0 ]
        then
        linei=0
        SIGNATUREHTML="zimbraPrefMailSignatureHTML:"
        SIGNATUREPLAIN="zimbraPrefMailSignature:"
        SIGNATUREID="zimbraSignatureId:"
        SIGNATURENAME="zimbraSignatureName:"
        SIGNATURETYPE=""
        SIGNATUREADD="0"
        echo "Signature import for $i"
          while read -r LINE
          do
            
            if [[ ${LINE} == *"${SIGNATUREHTML}"* ]]; then
            zimbraPrefMailSignatureHTML=${LINE/zimbraPrefMailSignatureHTML:/}
            zimbraPrefMailSignatureHTML=`echo $zimbraPrefMailSignatureHTML | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
            zimbraPrefMailSignatureHTML=${zimbraPrefMailSignatureHTML//\"/\\\"}
            SIGNATURETYPE="HTML"
            SIGNATUREADD="0"
            continue
            fi

            if [[ ${LINE} == *"${SIGNATUREPLAIN}"* ]]; then
            zimbraPrefMailSignature=${LINE/zimbraPrefMailSignature:/}
            zimbraPrefMailSignature=`echo $zimbraPrefMailSignature | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
            zimbraPrefMailSignature=${zimbraPrefMailSignature//\"/\\\"}
            SIGNATURETYPE="PLAIN"
            SIGNATUREADD="1"
            continue
            fi
        
            if [[ ${LINE} == *"${SIGNATUREID}"* ]]; then
                zimbraSignatureId=${LINE/zimbraSignatureId:/}
                zimbraSignatureId=`echo $zimbraySignatureId | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'` 
                SIGNATUREADD="0"
                continue
            fi
          
            if [[ ${LINE} == *"${SIGNATURENAME}"* ]]; then
              zimbraSignatureName=${LINE/zimbraSignatureName:/}
              #zimbraSignatureName=$(grep zimbraSignatureName: $LINE | cut -d ":" -f2)
              zimbraSignatureName=`echo $zimbraSignatureName | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`   
             
              # Create the Signature First
              /opt/zimbra/bin/zmprov csig $i "${zimbraSignatureName}"

              # Add HTML Signature 
              if [[ ${SIGNATURETYPE} == "HTML" ]]; then     
              echo "Execute Signature add /opt/zimbra/bin/zmprov msig $i ${zimbraSignatureName} zimbraPrefMailSignatureHTML ${zimbraPrefMailSignatureHTML}"  
              /opt/zimbra/bin/zmprov msig $i "${zimbraSignatureName}" zimbraPrefMailSignatureHTML "${zimbraPrefMailSignatureHTML}"
              fi
              
              if [[ ${SIGNATURETYPE} == "PLAIN" ]]; then  
              echo "Execute Signature add /opt/zimbra/bin/zmprov msig $i ${zimbraSignatureName} zimbraPrefMailSignature ${zimbraPrefMailSignature}"  
              /opt/zimbra/bin/zmprov msig $i "${zimbraSignatureName}" zimbraPrefMailSignature "${zimbraPrefMailSignature}" 
              fi

              SIGNATUREADD="0"
              SIGNATURETYPE="" 
              zimbraSignatureId=""
              zimbraSignatureName=""
              zimbraPrefMailSignature=""
              zimbraPrefMailSignatureHTML=""
              continue
            fi 

            if [[ ${SIGNATURETYPE} == "PLAIN" ]] && [[ ${SIGNATUREADD} -eq 1 ]]; then
              echo "Add Line to Plain text signature... Continue Loop per line"
              zimbraPrefMailSignature="${zimbraPrefMailSignature}
${LINE}"
            fi 
          ((linei=linei+1))
          done < "${BACKUP_DIR}/signatures/$i.txt"
        fi
    fi

    #Autoresponders
    if [ -e ${BACKUP_DIR}/autoresponders/$i.txt ]
    then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/autoresponders/$i.txt")
        if [ ${FILESIZE} -ne 0 ]
        then
        echo "Import Out Of Office for $i"
        zimbraPrefOutOfOfficeReply=$(grep zimbraPrefOutOfOfficeReply: ${BACKUP_DIR}/autoresponders/$i.txt | cut -d ":" -f2)
        zimbraPrefOutOfOfficeReply=`echo $zimbraPrefOutOfOfficeReply | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
        zimbraPrefOutOfOfficeReply=${zimbraPrefOutOfOfficeReply//\"/\\\"}
        zimbraPrefOutOfOfficeReplyEnabled=$(grep zimbraPrefOutOfOfficeReplyEnabled: ${BACKUP_DIR}/autoresponders/$i.txt | cut -d ":" -f2)
        zimbraPrefOutOfOfficeReplyEnabled=`echo $zimbraPrefOutOfOfficeReplyEnabled | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
        sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraPrefOutOfOfficeReply "$zimbraPrefOutOfOfficeReply"
        sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraPrefOutOfOfficeReplyEnabled "$zimbraPrefOutOfOfficeReplyEnabled"
        echo "Imported Out Of Office for $i"
        fi
    fi

    #Filters
    if [ -e ${BACKUP_DIR}/filters/$i.txt ]
    then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/filters/$i.txt")
      if [ ${FILESIZE} -gt 20 ]
      then
      echo "Import Filter for $i"  
      sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraMailSieveScript "`cat ${BACKUP_DIR}/filters/$i.txt`"
      echo "Imported Filter for $i"  
      fi
    fi
  done
  echo "Finished Importing Signatures and Autoresponders..."
fi

echo "Do you want to import contacts? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Contacts..."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
  #signatures
  if [ -e ${BACKUP_DIR}/contacts/$i.csv ]
  then
  FILESIZE=$(stat -c%s "${BACKUP_DIR}/contacts/$i.csv")
      if [ ${FILESIZE} -gt 25 ]
      then
      echo "Contacts import for $i"
      sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i pru /Contacts "${BACKUP_DIR}/contacts/$i.csv"
      #The curl method works too and is faster but requires admin password
      #curl -k -u admin:${ADMIN_PASSWORD} --upload-file '${BACKUP_DIR}/contacts/$i.csv' https://localhost:7071/home/$i/Contacts?fmt=csv 
      echo "Contacts imported for $i"
      fi
  fi  
  done  
fi 

# Import Calendars 
echo "Do you want to import Calendars? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Calendars..."  
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
    if [ -d ${BACKUP_DIR}/calendar/$i ]
    then
        for calendar in ${BACKUP_DIR}/calendar/$i/*.tgz
        do
        FILESIZE=$(stat -c%s "$calendar")
          if [ ${FILESIZE} -gt 0 ]
          then
          echo "Main Calendar: $calendar import for $i"
          sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i postRestURL "/?fmt=tgz&resolve=skip" "$calendar"
          echo "Main Calendar: $calendar imported for $i"
          fi
        done
    fi  
  done
  echo "Finished Importing Calendars..."  
fi 

echo "Do you want to import Briefcase? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Briefcase..."  
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
    if [ -d ${BACKUP_DIR}/briefcase/$i ]
    then
        for briefcase in ${BACKUP_DIR}/briefcase/$i/*.tgz
        do
        FILESIZE=$(stat -c%s "$briefcase")
          if [ ${FILESIZE} -gt 0 ]
          then
          echo "Main Briefcase: $briefcase import for $i"
          sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i postRestURL "/?fmt=tgz&resolve=skip" "$briefcase"
          echo "Main Briefcase: $briefcase imported for $i"
          fi
        done
    fi  
  done
  echo "Finished Importing Briefcases..."  
fi 

echo "Do you want to import forwarders? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Forwarders..."  
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
  #Import hidden forwarders
  if [ -e ${BACKUP_DIR}/forwarders/${i}_hidden.txt ]
  then
  FILESIZE=$(stat -c%s "${BACKUP_DIR}/forwarders/${i}_hidden.txt")
      if [ ${FILESIZE} -gt 1 ]
      then
          while read -r LINE
          do
             if [[ ${LINE} == *"zimbraMailForwardingAddress:"* ]]; then
              zimbraMailForwardingAddress=${LINE/zimbraMailForwardingAddress:/}
              zimbraMailForwardingAddress=`echo $zimbraMailForwardingAddress | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`  
              echo "Import Hidden forwarder for $i email $zimbraMailForwardingAddress"
              #delete the forwarder first just in case it was imported before
              sudo -u zimbra /opt/zimbra/bin/zmprov ma $i -zimbraMailForwardingAddress "${zimbraMailForwardingAddress}"
              sudo -u zimbra /opt/zimbra/bin/zmprov ma $i +zimbraMailForwardingAddress "${zimbraMailForwardingAddress}"
              echo "Imported Hidden forwarder for $i" 
             fi
          done < "${BACKUP_DIR}/forwarders/${i}_hidden.txt"
      fi
  fi  

  #Import hidden forwarders
  if [ -e ${BACKUP_DIR}/forwarders/${i}_userdefined.txt ]
  then
  FILESIZE=$(stat -c%s "${BACKUP_DIR}/forwarders/${i}_userdefined.txt")
      if [ ${FILESIZE} -gt 1 ]
      then
      zimbraPrefMailForwardingAddress=$(grep zimbraPrefMailForwardingAddress: ${BACKUP_DIR}/forwarders/${i}_userdefined.txt | cut -d ":" -f2)
      zimbraPrefMailForwardingAddress=`echo $zimbraPrefMailForwardingAddress | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
      echo "Import User Defined forwarder for $i email $zimbraPrefMailForwardingAddress"
      sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraPrefMailForwardingAddress ${zimbraPrefMailForwardingAddress}
      echo "Imported User Defined forwarder for $i email $zimbraPrefMailForwardingAddress"
      fi
  fi
  done  
fi 

echo "Do you want to import Aliases? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Aliases..."  
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
    if [ -e ${BACKUP_DIR}/alias/${i}.txt ]
    then
    FILESIZE=$(stat -c%s "${BACKUP_DIR}/alias/${i}.txt")
        if [ ${FILESIZE} -gt 1 ]
        then
            while read -r LINE
            do
               if [[ ${LINE} == *"zimbraMailAlias:"* ]]; then
                zimbraMailAlias=${LINE/zimbraMailAlias:/}
                zimbraMailAlias=`echo $zimbraMailAlias | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`  
                echo "Add Alias for $i with alias $zimbraMailAlias"
                sudo -u zimbra /opt/zimbra/bin/zmprov aaa $i ${zimbraMailAlias}
                echo "Added Alias for $i with alias $zimbraMailAlias"
               fi
            done < "${BACKUP_DIR}/alias/${i}.txt"
        fi
    fi 
  done  
fi 

echo "Do you want to import Distribution Lists? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  if [ -e ${BACKUP_DIR}/distribution_list.txt ]
  then
  echo "Start Import of Distribution List..."  
    for i in `cat ${BACKUP_DIR}/distribution_list.txt`
    do  
      #Import Distribution Lists
      if [ -e ${BACKUP_DIR}/distribution/${i}.txt ]
      then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/distribution/${i}.txt")
          if [ ${FILESIZE} -gt 1 ]
          then
          echo "Creating Distribution List ${i}"
          sudo -u zimbra /opt/zimbra/bin/zmprov CreateDistributionList $i 
              while read -r LINE
              do
                 if [[ ${LINE} == *"displayName:"* ]]; then
                  displayName=${LINE/displayName:/}
                  displayName=`echo $displayName | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  displayName=${displayName//\"/\\\"}  
                  echo "Modify Distribution List $i with Display Name $displayName"
                  sudo -u zimbra /opt/zimbra/bin/zmprov ModifyDistributionList $i displayName "${displayName}"
                 fi

                 if [[ ${LINE} == *"zimbraMailForwardingAddress:"* ]]; then
                  zimbraMailForwardingAddress=${LINE/zimbraMailForwardingAddress:/}
                  zimbraMailForwardingAddress=`echo $zimbraMailForwardingAddress | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`  
                  echo "Add member to Distribution List $i and add $zimbraMailForwardingAddress"
                  sudo -u zimbra /opt/zimbra/bin/zmprov AddDistributionListMember $i "${zimbraMailForwardingAddress}"
                 fi
              done < "${BACKUP_DIR}/distribution/${i}.txt"
          fi
      fi  
    done
  fi
fi 

echo "WARNING : This could take a long time so please use screen to avoid disconnection problems"
echo "Do you want to import Emails now? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  #Check whether imapsync is installed
  if command -v imapsync > /dev/null 2>&1; then
    echo "imapsync exists - great!"
    echo "Start Email Migration!"
    read -s -p "Please Enter Admin Password for the Old Server: " OLD_ADMIN_PASSWORD
    echo ""
    read -s -p "Please Enter Admin Password for the New Server: " NEW_ADMIN_PASSWORD
    for i in `cat ${BACKUP_DIR}/emails.txt`
    do  
    echo "Start Migration of emails for $i"
    echo "--------------------------------"
    echo ""
    sleep1 
    # before
    # imapsync --host1 ${SOURCE} --ssl1 --user1 $i --authuser1 admin --password1 ${OLD_ADMIN_PASSWORD} --host2 localhost --ssl2 --user2 $i --authuser2 admin --password2 ${NEW_ADMIN_PASSWORD} --noauthmd5 --sep1 / --prefix1 / --sep2 / --prefix2 "" 
    # imapsync --addheader --nosyncacls --syncinternaldates --nofoldersizes --host1 ${SOURCE} --ssl1 --user1 $i --authuser1 admin --password1 ${OLD_ADMIN_PASSWORD} --host2 localhost --ssl2 --user2 $i --authuser2 admin --password2 ${NEW_ADMIN_PASSWORD} --noauthmd5 --sep1 / --prefix1 / --sep2 / --prefix2 ""   
    # Need to divide up - if mailboxes are really large - read RESPONSE_VAR

    imapsync --addheader --errorsmax 100000 --nosyncacls --subscribe --syncinternaldates --nofoldersizes --skipsize --host1 ${SOURCE} --ssl1 --user1 $i --authuser1 admin --password1 ${OLD_ADMIN_PASSWORD} --host2 localhost --ssl2 --user2 $i --authuser2 admin --password2 ${NEW_ADMIN_PASSWORD} --noauthmd5 --sep1 / --prefix1 / --sep2 / --prefix2 "" --regexflag "s/:FLAG/_FLAG/g" --exclude "Chats"
    echo "Finished Migration of emails for $i"
    done  
  else
    echo "Imapsync does not exist"
    echo "Exiting...."
    exit 0
  fi
fi 

# Import Filters - Filters should be imported after Mailbox import
echo "Do you want to import filter? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Filters..."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
  #Filters
    if [ -e ${BACKUP_DIR}/filters/$i.txt ]
    then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/filters/$i.txt")
      if [ ${FILESIZE} -gt 20 ]
      then
      echo "Import Filter for $i"  
      sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraMailSieveScript "`cat ${BACKUP_DIR}/filters/$i.txt`"
      echo "Imported Filter for $i"  
      fi
    fi
  done  
fi 

  # Import Mailbox Preferences 
  echo "Do you want to import preferences? (y/n)"
  read RESPONSE_VAR
  if [ ${RESPONSE_VAR} == "y" ]
    then
    echo "Start Import of User Preferences..."
    for i in `cat ${BACKUP_DIR}/emails.txt`
    do  
      if [ -e ${BACKUP_DIR}/settings/${i}_prefs.txt ]
      then
      FILESIZE=$(stat -c%s "${BACKUP_DIR}/settings/${i}_prefs.txt")
        if [ ${FILESIZE} -gt 20 ]
        then
          while read -r LINE
            do
              for pref in "${IMPORT_PREF[@]}"
               do 
               REGEXPREF="${pref}:"
               if [[ ${LINE} == *"$REGEXPREF"* ]]; then
                PREFVALUE=${LINE/$REGEXPREF/}
                PREFVALUE=`echo $PREFVALUE | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                echo "Modify Pref for $i ${pref} $PREFVALUE"
                  if [[ $pref == "zimbraPrefMailTrustedSenderList" ]]
                  then
                  # zimbraPrefMailTrustedSenderList has multiple entries so we have to use +
                  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i +$pref $PREFVALUE
                  echo "Execute :  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i +$pref $PREFVALUE"  
                  elif [[ $pref == "zimbraPrefHtmlEditorDefaultFontFamily" ]]
                    then
                   sudo -u zimbra /opt/zimbra/bin/zmprov ma $i $pref \""$PREFVALUE"\" 
                   echo "Execute :  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i $pref $PREFVALUE"          
                  else 
                  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i $pref $PREFVALUE
                  echo "Execute :  sudo -u zimbra /opt/zimbra/bin/zmprov ma $i $pref $PREFVALUE"
                  fi
                echo "Finished Modify Pref for $i ${pref} $PREFVALUE"
               fi
             done
            done < "${BACKUP_DIR}/settings/${i}_prefs.txt"
        fi
      fi
    done  
  fi 

# Import Legal Intercepts
echo "Do you want to import legal intercepts settings? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Legal Intercepts..."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
    if [ -e ${BACKUP_DIR}/settings/${i}_intercept.txt ]
    then
    FILESIZE=$(stat -c%s "${BACKUP_DIR}/settings/${i}_intercept.txt")
      if [ ${FILESIZE} -gt 20 ]
      then
        while read -r LINE
          do
             if [[ ${LINE} == *"zimbraInterceptAddress:"* ]]; then
              intercept=${LINE/zimbraInterceptAddress:/}
              intercept=`echo $intercept | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`  
              intercept=`echo "'"$intercept"'"`
              echo "Add Legal Intercept for $i $intercept"
              sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraInterceptAddress $intercept
              echo "Finished Adding Legal Intercept for $i $intercept"
             fi
          done < "${BACKUP_DIR}/settings/${i}_intercept.txt"
      fi
    fi
  done  
fi 

#Import Shared Resources 
# Example Briefcase : zimbraSharedItem: granteeId:f8822818-3f39-4e27-a453-568e71f4fb09;granteeName:abc@xxxxx.com;granteeType:usr;folderId:182586;folderUuid:null;folderPath:/Notebook/XXXXSmith;folderDefaultView:document;rights:r;type:folder
# Example Calendar : zimbraSharedItem: granteeId:17131a6a-96af-4ea0-b89d-e610f56c2f37;granteeName:abc@xxxxx.com;granteeType:usr;folderId:10;folderUuid:53f6da37-e77b-42c2-af16-f7eb0b820489;folderPath:/Calendar;folderDefaultView:appointment;rights:rwidx;type:folder 

# For Calendar Share the following command works
# Raw data zimbraSharedItem: granteeId:74ba84f9-6d76-4fba-9c99-2d8091914afe;granteeName:grantee@grantee.com;granteeType:usr;folderId:10;folderUuid:53f6da37-e77b-42c2-af16-f7eb0b820489;folderPath:/Calendar;folderDefaultView:appointment;rights:r;type:folder
# zmmailbox -z -m $i mfg /Calendar account $email_of_grantee r
# r at the end refers to rights:r

# zimbraSharedItem: granteeId:f8822818-3f39-4e27-a453-568e71f4fb09;granteeName:grantee@grantee.com;granteeType:usr;folderId:182586;folderUuid:null;folderPath:/Notebook/XXXXSmith;folderDefaultView:document;rights:r;type:folder
# This works for Briefcases too:- zmmailbox -z -m email@email.com mfg '/Notebook/Shared' account grantee@grantee.com rwidx
# Directive modifyFolderGrant(mfg) {folder-path} {account {name}|group {name}|domain {name}|all|public|guest {email} [{password}]|key {email} [{accesskey}] {permissions|none}}
# zimbraShareLifetime: 0
# zimbraSharedItem: granteeId:roberto@macau.mo;granteeName:null;granteeType:guest;folderId:7;folderUuid:null;folderPath:/Contacts;folderDefaultView:contact;rights:r;type:folder

# Import Share Settings
echo "Do you want to import Share settings? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Share Settings (e.g. calendars, briefcases, etc...."
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
    if [ -e ${BACKUP_DIR}/settings/${i}_shared.txt ]
    then
    FILESIZE=$(stat -c%s "${BACKUP_DIR}/settings/${i}_shared.txt")
      if [ ${FILESIZE} -gt 25 ]
      then
        while read -r LINE
          do
            # check if the line contains Share Settins 
            if [[ ${LINE} == *"zimbraSharedItem:"* ]]; then
                #exploded=$(echo $LINE | tr ";" "\n")
                exploded=`sed 's/;/\n/g' <<< "${LINE}"`

                #for i in $(echo ${!exploded[@]});
                while read -r SHARELINE
                do 
                #SHARELINE=${exploded[$i]}
                #echo "SHARE LINE : $SHARELINE"
                
                #for SHARELINE in $exploded
                #  do
                  if [[ ${SHARELINE} == *"zimbraSharedItem:"* ]]; then
                  echo "New Share Item"
                  # Reset all variables
                  shareType=""
                  shareGrantee=""
                  shareFolder=""
                  shareRights=""
                  shareGranteeType=""
                  fi

                  if [[ ${SHARELINE} == *"folderDefaultView:"* ]]; then
                  shareType=${SHARELINE/folderDefaultView:/}
                  shareType=`echo $shareType | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  #echo "Type : $shareType"
                  fi

                  if [[ ${SHARELINE} == *"granteeName:"* ]]; then
                  shareGrantee=${SHARELINE/granteeName:/}
                  shareGrantee=`echo $shareGrantee | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  #echo "Grantee : $shareGrantee"
                  fi

                  if [[ ${SHARELINE} == *"granteeType:"* ]]; then
                  shareGranteeType=${SHARELINE/granteeType:/}
                  shareGranteeType=`echo $shareGranteeType | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  #echo "Grantee Type : $shareGranteeType"
                  fi

                  if [[ ${SHARELINE} == *"folderPath:"* ]]; then
                  #shareFolder=${SHARELINE/folderPath:/}
                  shareFolder=`echo ${SHARELINE} | cut -d ":" -f2`
                  #shareFolder=`echo $shareFolder | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  # Add single quotes just in case there are spaces in the folder names 
                  # shareFolder=`echo "'"$shareFolder"'"`
                  #echo "Share Folder : $shareFolder"
                  fi

                  if [[ ${SHARELINE} == *"rights:"* ]]; then
                  shareRights=${SHARELINE/rights:/}
                  shareRights=`echo $shareRights | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
                  #echo "Share Rights : $shareRights"
                  fi

                  #If all variables set then we can set in Zimbra
                  if [[ -n "$shareRights" && -n "$shareFolder" && -n "$shareGrantee" && -n "$shareGranteeType" ]]; then 

                    # don't add guest yet for sharing
                    if [[ $shareGranteeType == "usr" ]]; then
                    echo "Execute"
                    echo "sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i mfg $shareFolder account $shareGrantee $shareRights"
                    sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i mfg "${shareFolder}" account "$shareGrantee" "$shareRights"
                    echo "Executed"
                    fi
                  # Reset all variables
                  shareType=""
                  shareGrantee=""
                  shareFolder=""
                  shareRights=""
                  shareGranteeType=""  
                  fi 
                done <<< "$exploded"
            fi
          done < "${BACKUP_DIR}/settings/${i}_shared.txt"
      fi
    fi
  done  
fi
