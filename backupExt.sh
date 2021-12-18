#!/bin/bash

# ------------------------------------------------------------------------------
#  © Copyright (с) 2021
#  Author: Dmitri Agababaev, d.agababaev@duncat.net
# ------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# ----- default params -----

optPosition=1
optCount=$#

srcPath=""
default_scrPath="/etc" # or $MY_SRCBACKUP_PATH
dstPath=""
default_dstPath="/usr/local/backup" # or $MY_DSTBACKUP_PATH
backupName="backup"

# additional options
mailToAddr=""
excludeFiles=""
zipRatio=6
verbose=""
lastBackupCount=3

# --------------------------

help() {
  echo ""
  echo "Avaiaible options for this script:"
  echo "-h   | --help                Show help"
  echo "-df  | --default             Create default backup (backup files from /etc to /usr/local/backup)"
  echo "-n   | --name                Name of backup (date of creation will be added by script), default – backup  (example: -n mybackupname)"
  echo "-f   | --src-file            Path to source file (example: -src ~/dir/file.log)"
  echo "-d   | --src-directory       Path to source folder (example: -src ~/dir)"
  echo "-dst | --dst-path            Path to destination folder (example: -dst ~/backup_dir)"
  echo "-cr  | --compression-ratio   Compression ratio of gzip (example: -cr 9)"
  echo "-ex  | --exclude-files       Exclude files from backup by mask (example: -ex *.jpg -ex *.png)"
  echo "-em  | --email               Send notification to email (example: -em name@hostname.com)"
  echo "-p   | --purge               Leave only N latest backup in destination (example: -p 3 ~/backup_dir). Allowed if this option set at the beginning and it one"
  echo "-v   | --verbose             Verbose output"
  echo ""
  echo "The sequence doesn't matter. Example:"
  echo "bash backupExt.sh -v -ex *.php -ex *.png -f ~/file1.php -f ~/file2.log -d ~/folder1 -dst ~/destination_folder -cr 9 --email user@host.com --name myBackup"
  echo ""
  exit 0
}

# checking if option has argument
checkArgument() {
  # checking if argument for option isset. if at the start --, that is new option and arg is not set
  if [[ -z $2 ]] || [[ $2 == --* ]] || [[ $2 == -* ]]; then
    echo -en "${RED}Error!${NC} Argument for option $1 is required\n" 1>&2
    exit 1
  fi
}

# checking if source file/folder is exist
checkIfSourceExist() {
  if [ ! $1 $2 ]; then
     echo -en "${RED}FAILED:${NC} Source $2 doesn't exist\n"
     exit 1
  fi
}

# verbose output
verbose() {
  [[ -z $verbose ]] && return
  echo -en $1"\n"
}

# perge older backup files
purge() {
  cd $2 && ls -t *.gz | awk "NR>$1" | xargs rm -f
  [[ $? == 0 ]] &&  taskStatus="${GREEN}SUCCESSFUL:${NC}" || taskStatus="${RED}FAILED:${NC}"
  echo -en "$taskStatus Purge older backups. Leave only $1\n"
  exit 0
}

createBackup() {

  date=$(date +%d-%m-%Y_%H-%M-%S)
  # if src-path is empty – get default value
  [[ -z $srcPath ]] && srcPath=$default_scrPath
  # if dst-path is empty – get default value
  [[ -z $dstPath ]] && dstPath=$default_dstPath

  verbose "Backup started at $date ..."
  filename="$backupName-$(date +%d-%m-%Y_%H-%M-%S).tar.gz"

  verbose "Checking if destination folder exist ..."
  if [ ! -d $dstPath ]; then
     verbose "Destination folder doesn't exist, trying to create it ..."
     mkdir -p $dstPath 2>/dev/null
     if [[ $? == 0 ]] ; then
       verbose "${GREEN}SUCCESSFUL${NC} – Destination folder created"
     else
        echo -en "${RED}FAILED:${NC} Can't create destination folder. Try to use sudo.\n"
        exit 1
     fi
  fi

  # command filling
  cmd="tar $excludeFiles -cvf - $srcPath | gzip -$zipRatio > $dstPath"/"$filename"
  # run backup
  echo $cmd
  verbose "Archivation starting ..."
  eval $cmd 2>/dev/null

  # cmd response
  [[ $? == 0 ]] && taskStatus="${GREEN}SUCCESSFUL:${NC}" || taskStatus="${RED}FAILED:${NC}"
  echo -en "$taskStatus Task of creation backup $filename\n"

  # send email if -em isset
  [[ $mailToAddr ]] && notification $taskStatus

  exit 0

}

notification() {
  # sent simple email notification
  verbose "Trying to send email notification to $mailToAddr ..."
  # echo "Task of creation backup $filename is: $1" | mail -s "Backup status" $mailToAddr;
  [[ $? == 0 ]] && verbose "Email sended ${GREEN}successfuly${NC}" || verbose "Email sending is ${RED}FAILED${NC}"
}


# ------------ PARSING ARGS ---------------
# if script run without any option/arguments, show help
if [[ $optCount == 0 ]]; then
  help
fi

# start parsing
while [[ $optPosition -le $optCount ]]; do
  case $1 in
    -h | --help)
      # if position of argument more then 1, means that other options is sets
      if [[ $optPosition -lt 2 ]]; then
        help
      fi
      ;;
    -df | --default)
      # if position of argument more then 1, means that other options is sets
      if [[ $optPosition -lt 2 ]]; then
        createBackup
      fi
      ;;
    -p | --purge)
      # if position of argument more then 1, means that other options is sets
      if [[ $optPosition -lt 2 ]]; then
        checkArgument $1 $2
        purge $2 $3
      fi
      ;;
    -n | --name)
      checkArgument $1 $2
      backupName=$2
      ;;
    -f | --src-file)
      checkArgument $1 $2
      checkIfSourceExist -f $2
      srcPath="$srcPath $2"
      ;;
    -d | --src-directory)
      checkArgument $1 $2
      checkIfSourceExist -d $2
      srcPath="$srcPath $2"
      ;;
    -dst | --dst-path)
      checkArgument $1 $2
      dstPath=$2
      ;;
    -cr | --compression-ratio)
      checkArgument $1 $2
      zipRatio=$2
      ;;
    -ex | --exclude-files)
      checkArgument $1 $2
      excludeFiles="$excludeFiles--exclude='$2' "
      ;;
    -em | --email)
      checkArgument $1 $2
      mailToAddr=$2
      ;;
    -p | --purge)
      checkArgument $1 $2
      mailToAddr=$2
      ;;
    -v | --verbose)
      verbose="1"
      ;;
  esac
  optPosition=$((optPosition + 1))
  shift 1
done

createBackup

exit 0
