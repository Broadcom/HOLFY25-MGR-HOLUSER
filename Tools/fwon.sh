#!/bin/bash
# version 1.1 2025-12-03
# modernized to use bash syntax

ubuntu=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -f2 -d '=')

if [[ ${ubuntu} == "20.04" ]]; then
   # get the password from vPod.txt
   if [[ -f /tmp/vPod.txt ]]; then
      password=$(grep password /tmp/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)
   else
      password=$(grep password /hol/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)
   fi
else
   password=$(cat /home/holuser/creds.txt)
fi

/usr/bin/sshpass -p "$password" ssh root@router /root/fwupdate.sh --on
echo "Please re-enable proxy settings for browser and command line."
