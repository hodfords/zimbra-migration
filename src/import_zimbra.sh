#!/bin/bash
#
# Written by Hodfords.com Ltd (https://www.hodfords.com/)
# Released under GNU General Public License v3 (GPL-3)
#
# This script is free for anyone to use and can be distributed freely 
#
# You are solely responsible for adequate protection and backup of the data and equipment used in connection with any of this script, and we will not be liable for any damages that you may suffer connection with downloading, installing, using, modifying or distributing such script.
## To be run on the destination server (the new server that you are migrating to) - Assumes that you are running Zimra 8 or above
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


echo "Do you want to import Signatures, Autoresponders and Filters (y/n)?"
sleep 1
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Signatures, Autoresponders and Filters..."
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
        ##zimbraPrefMailSignatureHTML=$(grep zimbraPrefMailSignatureHTML: ${BACKUP_DIR}/signatures/$i.txt | cut -d ":" -f2)
        ##zimbraPrefMailSignatureHTML=`echo $zimbraPrefMailSignatureHTML | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
        ##zimbraSignatureId=$(grep zimbraSignatureId: ${BACKUP_DIR}/signatures/$i.txt | cut -d ":" -f2)
        ##zimbraSignatureId=`echo $zimbraySignatureId | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
        ##zimbraSignatureName=$(grep zimbraSignatureName: ${BACKUP_DIR}/signatures/$i.txt | cut -d ":" -f2)
        ##zimbraSignatureName=`echo $zimbraSignatureName | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`
        ##sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraPrefMailSignatureHTML "$zimbraPrefMailSignatureHTML"
        ##sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraSignatureId "$zimbraSignatureId"
        ##sudo -u zimbra /opt/zimbra/bin/zmprov ma $i zimbraSignatureName "$zimbraSignatureName"
        ##echo "Signature imported for $i with ID $zimbraSignatureId"
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
  echo "Finished Importing Signatures, Autoresponders and Filters..."
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
      /opt/zimbra/bin/zmmailbox -z -m $i pru /Contacts "${BACKUP_DIR}/contacts/$i.csv"
      #The curl method works too and is faster but requires admin password
      #curl -k -u admin:${ADMIN_PASSWORD} --upload-file '${BACKUP_DIR}/contacts/$i.csv' https://localhost:7071/home/$i/Contacts?fmt=csv 
      echo "Contacts imported for $i"
      fi
  fi  
  done  
fi 

echo "Do you want to import calendars? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Calendars..."  
  #read -s -p "Please Enter Admin Password for the New Server: " ADMIN_PASSWORD
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
  #signatures
  if [ -e ${BACKUP_DIR}/calendar/$i.tgz ]
  then
  FILESIZE=$(stat -c%s "${BACKUP_DIR}/calendar/$i.tgz")
      if [ ${FILESIZE} -gt 0 ]
      then
      echo "Calendars import for $i"
      #/opt/zimbra/bin/zmmailbox -z -m $i postRestURL "/Calendar/?fmt=ics&resolve=skip" "${BACKUP_DIR}/calendar/$i.ics"
      /opt/zimbra/bin/zmmailbox -z -m $i postRestURL "/?fmt=tgz&resolve=skip" "${BACKUP_DIR}/calendar/$i.tgz"
      #curl -k -u admin:${ADMIN_PASSWORD} --upload-file '${BACKUP_DIR}/calendar/$i.ics' https://localhost:7071/home/$i/calendar?fmt=ics 
      echo "Calendars imported for $i"
      fi
  fi  
  done  
fi 

echo "Do you want to import Briefcase? (y/n)"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} == "y" ]
  then
  echo "Start Import of Briefcase..."  
  #read -s -p "Please Enter Admin Password for the New Server: " ADMIN_PASSWORD
  for i in `cat ${BACKUP_DIR}/emails.txt`
  do  
  #signatures
  if [ -e ${BACKUP_DIR}/briefcase/$i.tgz ]
  then
  FILESIZE=$(stat -c%s "${BACKUP_DIR}/briefcase/$i.tgz")
      if [ ${FILESIZE} -gt 0 ]
      then
      echo "Briefcase import for $i"
      /opt/zimbra/bin/zmmailbox -z -m $i postRestURL "/Briefcase/?fmt=tgz&resolve=skip" "${BACKUP_DIR}/briefcase/$i.tgz"
      #curl -k -u admin:${ADMIN_PASSWORD} --upload-file '${BACKUP_DIR}/calendar/$i.ics' https://localhost:7071/home/$i/calendar?fmt=ics 
      echo "Briefcase imported for $i"
      fi
  fi  
  done  
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
    #Import hidden forwarders
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
                #delete the forwarder first just in case it was imported before
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
    imapsync --host1 ${SOURCE} --ssl1 --user1 $i --authuser1 admin --password1 ${OLD_ADMIN_PASSWORD} --host2 localhost --ssl2 --user2 $i --authuser2 admin --password2 ${NEW_ADMIN_PASSWORD} --noauthmd5 --sep1 / --prefix1 / --sep2 / --prefix2 ""   
    echo "Finished Migration of emails for $i"
    done  
  else
    echo "Imapsync does not exist"
    echo "Exiting...."
    exit 0
  fi
fi 
