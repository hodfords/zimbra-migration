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
# The script will create backup of domains, users, passwords, calendars, contacts, briefcases, mailfilters, auto-responders, preferences, shared resources
# The migration of mailbox should be done with import_zimbra.sh (if you are migrating to another Zimbra server)
# 
## Tested running Zimbra 8.8.15 
## Script Name : export_zimbra.sh
## 
## Recommended location : /opt/scripts/export_zimbra.sh
## Remember to make the script executable by running: chmod 755 /opt/scripts/export_zimbra.sh
# 
# To export only the accounts for a single domain run  ./export_zimbra.sh xxxx.com
BACKUP_DIR="/opt/zmbackup"
REGEX_FOLDER_TOP="\/[^\/]+"

sudo -u zimbra bash -c 'export LC_ALL="en_US.UTF-8"'
export LC_ALL="en_US.UTF-8"

echo "This script should be run as root.... Maybe exit now with Ctrl-c if not"
sleep 1

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

cd ${BACKUP_DIR}

echo "--------------------------------------------------"
echo "To Confirm migration start we will be exporting data to: ${BACKUP_DIR}"
echo "Please note that anything in the directory will be overwritten."
echo "--------------------------------------------------"
echo ""
echo "Do you want to proceed with the export process (y/n)?"
read RESPONSE_VAR
if [ ${RESPONSE_VAR} != "y" ]
  then
  echo "exiting..."
  exit 0
fi 

if [ ! -n "$1" ]
  then
        echo "Will export all domains"
        DOMAIN="OFF"
  else
        echo "Will only export for Domain : $1"
        echo ""
        DOMAIN=$1
        sleep 1
fi

## Export coses
##echo "Exporting coses..."
##/opt/zimbra/common/sbin/slapcat -F /opt/zimbra/data/ldap/config -b "" -s "cn=cos,cn=zimbra" -H ldap:///???(&(objectClass=zimbraCos)(!(cn=default))(!(cn=defaultExternal))) -l ${BACKUP_DIR}/coses.ldif

## Export domains
if [ ! -n "$1" ]
then
echo "Exporting all domains..."
sudo -u zimbra /opt/zimbra/bin/zmprov -l gad > ${BACKUP_DIR}/domains.txt
chown -R zimbra:zimbra ${BACKUP_DIR}/domains.txt
else 
echo "Exporting only accounts for ${DOMAIN}"
#DOMAINRESULT=$(sudo -u zimbra /opt/zimbra/bin/zmprov -l gad 2>&1)
DOMAINRESULT=$(sudo -u zimbra /opt/zimbra/bin/zmprov -l gd ${DOMAIN} 2>&1)
  if [ "$DOMAINRESULT" == *"NO_SUCH_DOMAIN"* ]; then
  echo "Domain name ${DOMAIN} does not exist"
  exit
  else 
  echo ${DOMAIN} > ${BACKUP_DIR}/domains.txt
  chown -R zimbra:zimbra ${BACKUP_DIR}/domains.txt
  fi
fi

## Export Users
if [ ! -n "$1" ]
then
echo "Exporting users..."
sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa > ${BACKUP_DIR}/emails.txt
chown -R zimbra:zimbra ${BACKUP_DIR}/emails.txt
else 
echo "Exporting only users for ${DOMAIN}"
sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa ${DOMAIN} > ${BACKUP_DIR}/emails.txt
chown -R zimbra:zimbra ${BACKUP_DIR}/emails.txt
fi

## Display Output
echo "Domains Output:-"
cat ${BACKUP_DIR}/domains.txt 

echo "Users Output:-"
cat ${BACKUP_DIR}/emails.txt 

## Export Password
## Create Password Directory
if [ ! -d "$BACKUP_DIR"/userpass ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/userpass..."
  mkdir ${BACKUP_DIR}/userpass
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/userpass..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/userpass
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/userpass..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/userpass..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/userpass
fi

echo "Exporting user passwords... (will take 15 minutes)"
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov  -l ga $i userPassword | grep userPassword: | awk '{ print $2}' > ${BACKUP_DIR}/userpass/$i.shadow; done
echo "Exporting user passwords completed..."

## Export User Data 
## Create User Data Directory
if [ ! -d "$BACKUP_DIR"/userdata ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/userdata..."
  mkdir ${BACKUP_DIR}/userdata
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/userdata..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/userdata
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/userdata...(will take 15 minutes)"
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/userdata..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/userdata
fi

echo "Exporting user data..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i  | grep -i Name: > ${BACKUP_DIR}/userdata/$i.txt ; done
echo "Exporting user data completed..."

## Display Output
echo "Domains Output of User pass + data:-"
ls -llR ${BACKUP_DIR}/userdata/ ${BACKUP_DIR}/userpass/

## Export Contacts Events
if [ ! -d "$BACKUP_DIR"/contacts ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/contacts..."
  mkdir ${BACKUP_DIR}/contacts
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/contacts..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/contacts
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/contacts..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/contacts..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/contacts
fi

echo "Exporting contacts..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i getRestURL "/Contacts?fmt=csv" > ${BACKUP_DIR}/contacts/$i.csv; echo -e "Finished downloading Contacts of $i";done
echo -en ''
sleep 1

## Export Mail Filter Rules
if [ ! -d "$BACKUP_DIR"/filters ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/filters..."
  mkdir ${BACKUP_DIR}/filters
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/filters..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/filters
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/filters..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/filters..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/filters
fi

echo "Exporting Filters..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov -l ga  $i zimbraMailSieveScript > ${BACKUP_DIR}/filters/$i.txt; sed -i -e "1d" ${BACKUP_DIR}/filters/$i.txt; sed -i -e 's/zimbraMailSieveScript: //g' ${BACKUP_DIR}/filters/$i.txt; done
echo "Finished Exporting Filters..."

## Export Signatures
if [ ! -d "$BACKUP_DIR"/signatures ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/signatures..."
  mkdir ${BACKUP_DIR}/signatures
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/signatures..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/signatures
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/signatures..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/signatures..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/signatures
fi

echo "Exporting signatures..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov gsig $i > ${BACKUP_DIR}/signatures/$i.txt ; done
echo "Finished Exporting signatures..."

## Export AutoResponders
if [ ! -d "$BACKUP_DIR"/autoresponders ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/autoresponders..."
  mkdir ${BACKUP_DIR}/autoresponders
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/autoresponders..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/autoresponders
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/autoresponders..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/autoresponders..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/autoresponders
fi

echo "Exporting Auto-Responders..."
for i in `cat ${BACKUP_DIR}/emails.txt`
do 
sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep Office > ${BACKUP_DIR}/autoresponders/${i}.txt
sudo -u zimbra /opt/zimbra/bin/zmprov ga $i zimbraPrefOutOfOfficeReply > ${BACKUP_DIR}/autoresponders/${i}_reply.txt
done
chown -R zimbra:zimbra ${BACKUP_DIR}/autoresponders/
echo "Finished Exporting Auto-Responders..."

## Export Distribution Lists
if [ ! -d "$BACKUP_DIR"/distribution ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/distribution..."
  mkdir ${BACKUP_DIR}/distribution
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/distribution..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/distribution
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/distribution..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/distribution..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/distribution
fi

#export Distribution Lists
echo "Exporting All Distribution Lists..."
sudo -u zimbra /opt/zimbra/bin/zmprov GetAllDistributionLists > ${BACKUP_DIR}/distribution_list.txt
chown -R zimbra:zimbra ${BACKUP_DIR}/distribution_list.txt
for i in `cat ${BACKUP_DIR}/distribution_list.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov GetDistributionList $i > ${BACKUP_DIR}/distribution/$i.txt ; done
echo "Finished Exporting Distribution Lists"
#Finished export Distribution Lists

#Export Aliases
if [ ! -d "$BACKUP_DIR"/alias ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/alias..."
  mkdir ${BACKUP_DIR}/alias
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/alias..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/alias
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/alias..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/alias..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/alias
fi

#export Alias
echo "Exporting Aliases..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep zimbraMailAlias > ${BACKUP_DIR}/alias/$i.txt ; done
echo "Exported All Aliases..."


#Export Forwarders
if [ ! -d "$BACKUP_DIR"/forwarders ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/forwarders..."
  mkdir ${BACKUP_DIR}/forwarders
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/forwarders..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/forwarders
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/forwarders..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/forwarders..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/forwarders
fi

#export forwarders
echo "Exporting forwarders..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep 'zimbraMailForwardingAddress:' > ${BACKUP_DIR}/forwarders/${i}_hidden.txt ; done
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep 'zimbraPrefMailForwardingAddress:' > ${BACKUP_DIR}/forwarders/${i}_userdefined.txt ; done
echo "Exported All forwarders..."

#export Settings 
if [ ! -d "$BACKUP_DIR"/settings ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/settings..."
  mkdir ${BACKUP_DIR}/settings
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/settings..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/settings
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/settings..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/settings..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/settings
fi

echo "Exporting Global Settings..."
HOSTNAME=`sudo -u zimbra  /opt/zimbra/bin/zmhostname`
sudo -u zimbra /opt/zimbra/bin/zmprov gs ${HOSTNAME} > ${BACKUP_DIR}/global_settings.txt
chown -R zimbra:zimbra ${BACKUP_DIR}/global_settings.txt
echo "Exported Global Settings"

#export forwarders
echo "Exporting individual settings..."
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i getAllFolders > ${BACKUP_DIR}/settings/${i}_folders.txt ; done
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep zimbraPref > ${BACKUP_DIR}/settings/${i}_prefs.txt ; done
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep zimbraShare > ${BACKUP_DIR}/settings/${i}_shared.txt ; done
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep zimbraIntercept > ${BACKUP_DIR}/settings/${i}_intercept.txt ; done
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i | grep "zimbraAccountStatus:" > ${BACKUP_DIR}/settings/${i}_status.txt ; done

#catchall information is only available on the individual email
for i in `cat ${BACKUP_DIR}/emails.txt`; do sudo -u zimbra /opt/zimbra/bin/zmprov ga $i zimbraMailCatchAllAddress > ${BACKUP_DIR}/settings/${i}_catchall.txt ; done

echo "Exported individual settings..."

## Export Briefcase
if [ ! -d "$BACKUP_DIR"/briefcase ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/briefcase..."
  mkdir ${BACKUP_DIR}/briefcase
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/briefcase..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/briefcase
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/briefcase..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/briefcase..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/briefcase
fi

echo "Exporting Briefcase..."
for i in `cat ${BACKUP_DIR}/emails.txt`
do
  if [ ! -d "$BACKUP_DIR"/briefcase/${i} ]; then
  mkdir ${BACKUP_DIR}/briefcase/${i}
  chown -R zimbra:zimbra ${BACKUP_DIR}/briefcase/${i}
  fi

  # Go through to see what folders are available 
  if [ -e ${BACKUP_DIR}/settings/${i}_folders.txt ]
  then
  declare -A folderarray  
    while read -r LINE
        do
          if [[ ${LINE} == *"  docu "* ]]; then
            #We only need to export the top level of any folder 
            [[ ${LINE} =~ $REGEX_FOLDER_TOP ]]
            INDEX1=${BASH_REMATCH[0]}
            folderarray[$INDEX1]="1"
          fi
        done < "${BACKUP_DIR}/settings/${i}_folders.txt"
  fi

  #output all briefcase folders 
  for folder in "${!folderarray[@]}"
  do 
    #The reason for this is that shared folders from other accounts can be here and we don't really want to export those 
    if [[ $folder != *")"* ]]; then
    echo "Export Folder : $folder"
    sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i getRestURL "${folder}/?fmt=tgz" > "${BACKUP_DIR}/briefcase/${i}${folder}.tgz"
    echo "Finished Exporting Folder : $folder"
    fi
  done
unset folderarray
unset folder
done
echo "Finished Exporting Briefcase..."


## Export Calendar Events
if [ ! -d "$BACKUP_DIR"/calendar ]; then
  # Create directory
  echo "Creating ${BACKUP_DIR}/calendar..."
  mkdir ${BACKUP_DIR}/calendar
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/calendar..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/calendar
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/calendar..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/calendar..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/calendar
fi

echo "Exporting Calendars..."
for i in `cat ${BACKUP_DIR}/emails.txt`
do 

  if [ ! -d "$BACKUP_DIR"/calendar/${i} ]; then
  mkdir ${BACKUP_DIR}/calendar/${i}
  chown -R zimbra:zimbra ${BACKUP_DIR}/calendar/${i}
  fi
  
  #sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i getRestURL "/Calendar?fmt=tgz" > ${BACKUP_DIR}/calendar/$i/Calendar.tgz
  if [ -e ${BACKUP_DIR}/settings/${i}_folders.txt ]
  then
  declare -A folderarray
    while read -r LINE
        do
          if [[ ${LINE} == *"  appo "* ]]; then
            #We only need to export the top level of any folder 
            [[ ${LINE} =~ $REGEX_FOLDER_TOP ]]
            INDEX1=${BASH_REMATCH[0]}
            folderarray[$INDEX1]="1"
          fi
        done < "${BACKUP_DIR}/settings/${i}_folders.txt"
  fi

  #output all calendars 
  for folder in "${!folderarray[@]}"
  do 
    #The reason for this is that shared folders from other accounts can be here and we don't really want to export those 
    if [[ $folder != *")"* ]]; then
    echo "Export Calendar Folder : $folder"
    sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $i getRestURL "${folder}/?fmt=tgz" > "${BACKUP_DIR}/calendar/${i}${folder}.tgz"
    echo "Finished Exporting Calendar Folder : $folder"
    fi
  done
unset folderarray
unset folder
echo -e "Finished exporting Calendar(s) of $i"
done
echo "Finished Exporting All Calendars"
echo -en ''
sleep 1

#Export Catch-all accounts
echo "Exporting Catch-alls..."
if [ ! -d "$BACKUP_DIR"/catchall ]; then
# Create directory
  echo "Creating ${BACKUP_DIR}/catchall..."
  mkdir ${BACKUP_DIR}/catchall
  echo "Chown zimbra:zimbra ${BACKUP_DIR}/catchall..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/catchall
else
  # Directory Found
  echo "Found ${BACKUP_DIR}/catchall..."
  echo "Chown just in case zimbra:zimbra ${BACKUP_DIR}/catchall..."
  chown -R zimbra:zimbra ${BACKUP_DIR}/catchall
fi

echo "Export Catch-alls..."
for i in `cat ${BACKUP_DIR}/domains.txt `; do sudo -u zimbra /opt/zimbra/bin/zmprov gd $i | grep CatchAll > ${BACKUP_DIR}/catchall/${i}.txt ; done
echo "Exported Catch-alls..."

