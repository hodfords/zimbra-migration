# Copyright 2023 Hodfords.com Ltd (https://www.hodfords.com/)
Released under GNU General Public License v3 (GPL-3)

This script is free for anyone to use and can be distributed freely 

You are solely responsible for adequate protection and backup of the data and equipment used in connection with any of this script, and we will not be liable for any damages that you may suffer connection with downloading, installing, using, modifying or distributing such script.

# Zimbra Migration Script
The script allows you to migrate emails, account passwords, domains, contacts, calendars, briefcases, auto-responders, filters and signatures between Zimbra installations. This script has been tested on 8.8.15 and allows you to transfer between Zimbra instances on different operating systems and different Zimbra versions. So in theory you can migrate from Zimbra 8 to 9 using this script. 

So this script allows you to migrate from Centos 6 to Centos 7 or Centos 8; or from Centos to Ubuntu and between different versions of Zimbra. 

There are 2 scripts; one for exporting all of the data which needs to be run on the server that you are migrating from and one for importing the data into the server that you are migrating to. The script is written in bash.

# How to Use
We recommend that the 2 scripts be put in /opt/scripts/. Before they can be run they need to be executable. export_zimbra.sh should be run on the server you are migrating from and will output all of the data to /opt/zmbackup/. Important to note that emails will not be exported as it would occupy too much storage. Instead emails are migrated using imapsync. 

