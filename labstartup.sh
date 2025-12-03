#!/bin/bash
# version 1.30 2025-12-03
# modernized to use bash syntax

git_pull() {
   cd "$1" || return
   ctr=0
   # stash uncommitted changes if not running in dev
   if [ $branch = "main" ];then
      echo "git stash local changes for prod." >> "${logfile}"
      git stash >> "${logfile}"
   else
      echo "Not doing git stash due to HOL-Dev." >> "${logfile}"
   fi
   while true; do
      if [[ $ctr -gt 30 ]]; then
         echo "Could not perform git pull. Will attempt LabStartup with existing code." >> "${logfile}"
         break  # just break so labstartup such as it is will run
      fi
      git checkout $branch >> ${logfile} 2>&1
      git pull origin $branch >> ${logfile} 2>&1
      if [[ $? -eq 0 ]]; then
        break
      else
        if grep -q 'could not be found' "${logfile}"; then
           gitproject=$(basename "$PWD")
           echo "The git project ${gitproject} does not exist." >> "${logfile}"
           echo "FAIL - No GIT Project" > "$startupstatus"
           exit 1
        else
           echo "Could not complete git pull. Will try again." >> "${logfile}"
        fi
     fi
     ((ctr++))
     sleep 5
   done
}

git_clone() {
   cd "$1" || return
   git init >> "${logfile}"
   git remote add origin "$gitproject" >> "${logfile}"
   echo "Performing git clone for repo ${vpodgit}" >> "${logfile}"
   # git clone -b dev https://github.com/Broadcom/HOL-2501.git /vpodrepo/2025-labs/2501
   echo "git clone -b $branch $gitproject $vpodgitdir" >> ${logfile}
   git clone -b "$branch" "$gitproject" "$vpodgitdir" >> ${logfile} 2>&1
}

runlabstartup() {
   # start the Python labstartup.py script with optional "labcheck" argument
   # we only want one labstartup.py running
   if ! pgrep -f "labstartup.py"; then
      echo "Starting ${holroot}/labstartup.py $1" >> "${logfile}"
      # -u unbuffered output
      /usr/bin/python3 -u "${holroot}/labstartup.py" "$1" >> "${logfile}" 2>&1 &
   fi
}

get_vpod_repo() {
   # get the vPod_SKU from $configini removing Windows carriage return if present
   vPod_SKU=$(grep vPod_SKU "${configini}" | grep -v '#' | cut -f2 -d= | sed 's/\r$//' | xargs)
   # calculate the git repo based on the vPod_SKU
   year=$(echo "${vPod_SKU}" | cut -c5-6)
   index=$(echo "${vPod_SKU}" | cut -c7-8)
   yearrepo="${gitdrive}/20${year}-labs"
   vpodgitdir="${yearrepo}/${year}${index}"
}

holroot=/home/holuser/hol
gitdrive=/vpodrepo
lmcholroot=/lmchol/hol
wmcholroot=/wmchol/hol
configini=/tmp/config.ini
logfile=/tmp/labstartupsh.log
sshoptions='StrictHostKeyChecking=accept-new'
LMC=false
WMC=false

# because we're running as an at or cron job, source the environment variables
# shellcheck source=/home/holuser/.bashrc
. /home/holuser/.bashrc

# if no command line argument
if [[ -z "$1" ]]; then
   # delete the old config.ini (not really needed but good for dev)
   rm "${configini}" > /dev/null 2>&1
fi

# remove all the at jobs before starting
for i in $(atq | awk '{print $1}'); do atrm "$i"; done

# pause until mount is present
while true; do
   if [[ -d ${lmcholroot} ]]; then
      echo "LMC detected." >> "${logfile}"
      mcholroot=${lmcholroot}
      desktopfile=/lmchol/home/holuser/desktop-hol/VMware.config
      [[ "$1" != "labcheck" ]] && cp /home/holuser/hol/Tools/VMware.config "$desktopfile"
      break
   elif [[ -d ${wmcholroot} ]]; then
      echo "WMC detected." >> "${logfile}"
      mcholroot=${wmcholroot}
      desktopfile=/wmchol/DesktopInfo/desktopinfo.ini
      [[ "$1" != "labcheck" ]] && cp /home/holuser/hol/Tools/desktopinfo.ini "$desktopfile"
      break
   fi
   echo "Waiting for Main Console mount to complete..." >> "${logfile}"
   sleep 5
done

startupstatus=${mcholroot}/startup_status.txt

# if run with the labcheck argument, only pass on to labstartup.py and exit
if [[ "$1" == "labcheck" ]]; then
   runlabstartup labcheck
   exit 0
else  # normal first run with no labcheck argument
   echo "Main Console mount is present. Clearing labstartup logs." >> "${logfile}"
   true > "${holroot}/labstartup.log"
   true > "${mcholroot}/labstartup.log"
   if [[ -f ${holroot}/vpodrouter/gitdone ]]; then
      rm "${holroot}/vpodrouter/gitdone"
   fi
fi

# copy the config.ini from the mainconsole to /tmp
if [[ -f ${mcholroot}/config.ini ]]; then
   echo "Copying ${mcholroot}/config.ini to ${configini}..." >> "${logfile}"
   cp "${mcholroot}/config.ini" "${configini}"
elif [[ -f ${mcholroot}/vPod.txt ]]; then
   echo "Copying ${mcholroot}/vPod.txt to /tmp/vPod.txt..." >> "${logfile}"
   cp "${mcholroot}/vPod.txt" /tmp/vPod.txt
else
   echo "No config.ini or vPod.txt on Main Console. Abort." >> "${logfile}"
   echo "FAIL - No vPod_SKU" > "$startupstatus"
   exit 1
fi

# did /root/mount.sh complete to volume preparation?
while [[ ! -d ${gitdrive}/lost+found ]]; do
   echo "Waiting for ${gitdrive}..."
   sleep 5
   if ! mount | grep -q "${gitdrive}"; then
      echo "" >> "${logfile}"
      echo "External ${gitdrive} not found. Abort." >> "${logfile}"
      echo "FAIL - No GIT Drive" > "$startupstatus"
      exit 1
   fi
done

ubuntu=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -f2 -d '=')

# the Core Team git pull is done using gitpull.sh at boot up
# still need to do the vPod git pull
if [[ -f ${configini} ]]; then
   echo "Getting vPod_SKU from ${configini}" >> "${logfile}"
   # get the vPod_SKU from $configini removing Windows carriage return if present
   vPod_SKU=$(grep vPod_SKU "${configini}" | grep -v '#' | cut -f2 -d= | sed 's/\r$//' | xargs)
   if [[ ${ubuntu} == "20.04" ]]; then
      # get the password from $config
      password=$(grep 'password =' "${configini}" | grep -v '#' | cut -f2 -d= | sed 's/\r$//' | xargs)
   else
      password=$(cat /home/holuser/creds.txt)
   fi
   # get the lab type
   labtype=$(grep 'labtype =' "${configini}" | grep -v '#' | cut -f2 -d= | sed 's/\r$//' | xargs)
   [[ -z "${labtype}" ]] && labtype="HOL"
   echo "labtype: $labtype" >> "${logfile}"
elif [[ -f /tmp/vPod.txt ]]; then
   echo "Getting vPod_SKU from /tmp/vPod.txt" >> "${logfile}"
   vPod_SKU=$(grep vPod_SKU /tmp/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)
   echo "vPod_SKU is ${vPod_SKU}" >> "${logfile}"
   if [[ ${ubuntu} == "20.04" ]]; then
      # get the password from $config
      password=$(grep password /tmp/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)
   else
      password=$(cat /home/holuser/creds.txt)
      [[ -d ${lmcholroot} ]] && cp /home/holuser/creds.txt /lmchol/home/holuser/creds.txt
   fi
   labtype=$(grep labtype /tmp/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)
fi

echo "$vPod_SKU" > /tmp/vPod_SKU.txt

# if labstartup has not been implemented, apply the default router rules
# then run labstartup.py which will update the desktop and exit
if [[ "$vPod_SKU" == "HOL-BADSKU" ]]; then
   echo "LabStartup not implemented." >> "${logfile}"
   # alert the router that the git pull is complete (at least the Core Team git pull)
   true > /home/holuser/hol/vpodrouter/gitdone
   # create /tmp/vpodrouter with contents on the router
   if [[ "${labtype}" == "HOL" ]]; then
      /usr/bin/sshpass -p "${password}" scp -o "${sshoptions}" -r "${holroot}/vpodrouter" holuser@router:/tmp
   fi
   runlabstartup
   exit 0
fi

# calculate the git repos based on the vPod_SKU
year=$(echo "${vPod_SKU}" | cut -c5-6)
index=$(echo "${vPod_SKU}" | cut -c7-8)

cloud=$(/usr/bin/vmtoolsd --cmd 'info-get guestinfo.ovfEnv' 2>&1)
holdev=$(echo "${cloud}" | grep -i hol-dev)
echo "labstartup.sh detected cloud: ${cloud} and holdev: ${holdev}" >> "${logfile}"
if [ "${cloud}" = "No value found" ] || [ ! -z "${holdev}" ];then 
   echo "labstartup.sh detected dev cloud. Setting branch to dev." >> "${logfile}"  
   branch="dev"
else
   echo "labstartup.sh detected prod cloud. Setting branch to main." >> "${logfile}"
   branch="main"
fi

gitproject="https://github.com/Broadcom/HOL-${year}${index}.git"

# this is the 2nd git pull for lab-specific captain updates
[ "$labtype" = "HOL" ] && echo "Ready to pull updates for ${vPod_SKU} from HOL gitlab ${gitproject}." >> ${logfile}

yearrepo="${gitdrive}/20${year}-labs"
yeargit="${yearrepo}/.git"
vpodgitdir="${yearrepo}/${year}${index}"
vpodgit="${vpodgitdir}/.git"

if [[ ${labtype} == "HOL" || ${vPod_SKU} == "HOL-2554" || ${vPod_SKU} == "HOL-2557" ]]; then

   # use git clone if local git repo is new else git pull for existing local repo
   if [[ ! -e ${yearrepo} || ! -e ${vpodgitdir} ]]; then
      echo "Creating new git repo for ${vPod_SKU}..." >> "${logfile}"
      mkdir "$yearrepo" > /dev/null 2>&1
      # if $vpodgitdir not exist git complains about fatal error
      # but the remote add but still completes so hide the error
      git_clone "$yearrepo" > /dev/null 2>&1
      if [[ $? -ne 0 ]]; then
         echo "The git project ${vpodgit} does not exist." >> "${logfile}"
         echo "FAIL - No GIT Project" > "$startupstatus"
         exit 1
      fi
   elif [[ ! -e ${yeargit} ]]; then
     # yearrepo exists but no .git
      echo "Creating new git repo for ${vPod_SKU}..." >> "${logfile}"
      git_clone "$yearrepo"
   else
      echo "Performing git pull for repo ${vpodgit}" >> "${logfile}"
      git_pull "$vpodgitdir"
   fi
   if [[ $? -eq 0 ]]; then
      echo "${vPod_SKU} git operations were successful." >> "${logfile}"
   else
      echo "Could not complete ${vPod_SKU} git clone." >> "${logfile}"
   fi
fi

# Git operations complete, replace placeholder with password throughout vpodgitdir before proceeding:
password=$(grep password /tmp/vPod.txt | cut -f2 -d '=' | sed 's/\r$//' | xargs)

if [ ! -d "${vpodgitdir}" ]; then
  echo "Error: Directory \"${vpodgitdir}\" not found."
  exit 1
fi

find "${vpodgitdir}" -type f -print0 | xargs -0 sed -i "s/{REPLACE_WITH_PASSWORD}/$password/g"
# Password replacement complete

if [[ -f ${vpodgitdir}/config.ini ]]; then
   cp "${vpodgitdir}/config.ini" "${configini}"
fi

# push the default router files for proxy filtering and iptables
if [[ "${labtype}" == "HOL" ]]; then
   # the router applies when the files arrive
   echo "Pushing default router files..." >> "${logfile}"
   /usr/bin/sshpass -p "${password}" scp -o "$sshoptions" -r "${holroot}/vpodrouter" holuser@router:/tmp
fi

# get the vPod_SKU router files to the hol folder which overwrites the Core Team default files (except allowlist)
skurouterfiles="${yearrepo}/${year}${index}/vpodrouter"
if [[ -d ${skurouterfiles} ]]; then
   if [[ "${labtype}" == "HOL" ]]; then
      echo "Updating router files from ${vPod_SKU}."  >> "${logfile}"
      # concatenate the allowlist files
      cp -r "${skurouterfiles}" /tmp
      cat "${holroot}/vpodrouter/allowlist" "${skurouterfiles}/allowlist" | sort | uniq > /tmp/vpodrouter/allowlist
      /usr/bin/sshpass -p "${password}" scp -o "${sshoptions}" -r /tmp/vpodrouter holuser@router:/tmp
   fi
elif [[ "${labtype}" == "HOL" ]]; then
   echo "Using default Core Team router files only."  >> "${logfile}"
fi
# alert the router that the git pull is complete so files are applied
if [[ "${labtype}" == "HOL" ]]; then
   /usr/bin/sshpass -p "${password}" ssh -o "${sshoptions}" holuser@router 'true > /tmp/vpodrouter/gitdone'
fi

# note that the gitlab pull is complete
true > /tmp/gitdone

if [[ -f ${configini} ]]; then
   runlabstartup
   echo "$0 finished." >> "${logfile}"
else
   echo "No config.ini on Main Console or vpodrepo. Abort." >> "${logfile}"
   echo "FAIL - No Config" > "$startupstatus"
   exit 1
fi 

