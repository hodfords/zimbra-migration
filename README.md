# Copyright 2023 Hodfords.com Ltd (https://www.hodfords.com/)
Released under GNU General Public License v3 (GPL-3)

This script is free for anyone to use and can be distributed freely 

You are solely responsible for adequate protection and backup of the data and equipment used in connection with any of this script, and we will not be liable for any damages that you may suffer connection with downloading, installing, using, modifying or distributing such script.

# Zimbra Migration Script
The script allows you to migrate emails, account passwords, domains, contacts, calendars, briefcases, auto-responders, filters, forwarders, aliases, distribution lists and signatures between Zimbra installations. This script has been tested on 8.8.15 and allows you to transfer between Zimbra instances on different operating systems and different Zimbra versions. So in theory you can migrate from Zimbra 8 to 9 using this script. 

So this script allows you to migrate from Centos 6 to Centos 7 or Centos 8; or from Centos to Ubuntu and between different versions of Zimbra. 

There are 2 scripts; one for exporting all of the data which needs to be run on the server that you are migrating from and one for importing the data into the server that you are migrating to. The script is written in bash.

# How to Use
We recommend that the 2 scripts be put in /opt/scripts/. Before they can be run they need to be executable. export_zimbra.sh should be run on the server you are migrating from and will output all of the data to /opt/zmbackup/. Important to note that emails will not be exported as it would occupy too much storage. Instead emails are migrated using imapsync. 

When running export_zimbra.sh and import_zimbra.sh make sure that Zimbra is running. 

To use:- 

To export Zimbra (To be run on the server that you are migrating from) - run as root
```
cd /opt/
mkdir scripts
cd scripts
wget https://raw.githubusercontent.com/hodfords/zimbra-migration/main/src/export_zimbra.sh
chmod 755 export_zimbra.sh
./export_zimbra.sh
```

Once all the data has finished exporting - you can import on the new server - run as root
```
cd /opt/
mkdir scripts
cd scripts
wget https://raw.githubusercontent.com/hodfords/zimbra-migration/main/src/import_zimbra.sh
chmod 755 import_zimbra.sh
./import_zimbra.sh 111.222.333.444
```

111.222.333.444 is the server address containing the export data and the server you are trying to migrate from.

# Required software on your servers 
- imapsync
- ability to run bash scripts
- cut
- rsync
- Zimbra should be running when you run the scripts
- sed
- cat
- stat
  
# Known Bugs
- During the export process - if your calendar has a lot of entries then Zimbra times out and the export process does not output the calendar at all.
This blog has a lot of really useful information:-
https://www.anahuac.eu/zimbra-to-carbonio-z2c/

And this might resolve the export and import issues. 
```
su zimbra
zmlocalconfig -e socket_so_timeout=99999999
zmlocalconfig --reload
```






