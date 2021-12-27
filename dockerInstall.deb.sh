#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# SETUP VARS
SILENT=""
OPT_POSITION=1
OPT_COUNT=$#

# GLOBAL VARIABLES
BIN_REMOVE_CMD=""
ACTION_TODO=""

RQ_PKGS=(curl ca-certificates gnupg lsb-release)
INSTALL_RQ_PKGS_CMD="apt install -y curl ca-certificates gnupg lsb-release"

FOUND_DOCKER=0
DOCKER_BIN=(docker containerd runc)
INSTALL_DOCKER_CMD="apt install -y docker-ce docker-ce-cli containerd.io"
UNINSTALL_DOCKER="apt remove -y $(dpkg -l | grep -i docker | echo $(cut -d " " -f 3)) docker-engine docker.io runc && apt remove containerd.io -y"
DOCKER_CONF_PATH="/etc/docker/daemon.json"
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"
DOCKER_COMPOSE_VERSION="v2.2.2"

# SETUP
LOG_MAX_SIZE="200m"
MAX_LOG_FILES=3

# HELP HERE
help() {
  echo "Avaiaible options for this script:"
  echo "-h    | --help                     Show this help"
  echo "-c    | --check                    Checking packages installed"
  echo "-lf   | --log-files                Count of log files"
  echo "-ls   | --log-size                 Maximum size of single log file in Mb"
  echo "-dcv  | --docker-compose-version   Version of Docker Compose (default - v2.2.2)"
  echo "-ia   | --install-all              Full instalation: required packages, docker, docker-compose"
  echo "-irp  | --install-req-packages     Install required packages only (curl ca-certificates gnupg lsb-release)"
  echo "-id   | --install-docker           Install Docker only (docker-ce docker-ce-cli containerd.io)"
  echo "                                   and setup default log rotation (3 log files / 200 Mb)"
  echo "-idc  | --install-docker-compose   Install Docker Compose only"
  echo "-rd   | --remove-docker            Remove Docker"
  echo "-rdc  | --remove-docker-compose    Remove Docker Compose"
  echo "-s    | --silent                   Silent install (without output)"
  exit 0
}

# VERBOUSE OUTPUT / ENABLED BY DEFAULT
v_echo() {
  # DON'T ECHO IF SILENT ISSET
  [[ -n $SILENT ]] && return ||  echo -en $1"\n"
}

# APT PACKAGE IS EXIST?
checkPKG() {
  dpkg -s $1 &>/dev/null
  [[ $? -eq 0 ]] && echo "true" || echo "false"
}

# BINARY FILE IS EXIST?
checkBIN() {
  which $1 &>/dev/null
  [[ $? -eq 0 ]] && echo "true" || echo "false"
}

# CHECK ARRAY OF NEEDED TO INSTALL
checkInstall() {
  # Find in installed packages
  for val in "${RQ_PKGS[@]}"; do
     local res=$(checkPKG $val)
     [[ $res == "true" ]] && v_echo "$val is ${GREEN}installed${NC} ..." || v_echo "$val is ${RED}not installed${NC} ..."
  done

  # Find binary files
  for val in "${DOCKER_BIN[@]}"; do
     local res=$(checkBIN $val)
     [[ $res == "true" ]] && v_echo "$val is ${GREEN}installed${NC} ..." || v_echo "$val is ${RED}not installed${NC} ..."
  done

  DC="Docker Compose is"
  [[ -f "/usr/local/bin/docker-compose" ]] && v_echo "$DC ${GREEN}installed${NC} ..." || v_echo "$DC ${RED}not installed${NC} ..."
}

# INSTALL REQUIRED PACKAGES
installReqPackages() {
  apt update &>/dev/null
  eval $INSTALL_RQ_PKGS_CMD
  if [[ $? -eq 0 ]]; then
    v_echo "${GREEN}Required packages successfuly installed${NC} ..."
  else
    v_echo "${RED}Installation of required packages end with errors${NC} ..." && exit 1
  fi
}

installDockerCompose() {

  v_echo "${GREEN}Start${NC} Docker Compose installation ..."

  DOCKER_COMPOSE_INSTALL="curl -L \"https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)\" -o $DOCKER_COMPOSE_PATH && chmod +x $DOCKER_COMPOSE_PATH"
  eval $DOCKER_COMPOSE_INSTALL

  if [[ $? -eq 0 ]]; then
    v_echo "${GREEN}Docker Compose install successfuly${NC} ..."
  else
    v_echo "${RED}Docker Compose installation end with errors${NC} ..." && exit 1
  fi
}

installDocker() {

  v_echo "${GREEN}Start${NC} Docker installation ..."

  for val in "${DOCKER_BIN[@]}"; do
     local res=$(checkBIN $val)
     echo "Find docker modules: $val - $res"
     [[ $res == "true" ]] && FOUND_DOCKER=1
  done

  if [[ $FOUND_DOCKER -eq 1 ]]; then
     v_echo "${RED}Found previous Docker instalation!${NC} ..."
     PS3="Do you want to delete it? (select number): "
     select answer in Yes No
     do
      case $REPLY in
          1) removeDocker; break;;
          2) echo "Leave old instalation..."; break;;
      esac
    done
  fi

  # Pre-install (update repo / get key / add repo )
  dkey="/usr/share/keyrings/docker-archive-keyring.gpg"; [[ -f $dkey ]] && rm $dkey
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && chmod a+r /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Start of main instalation
  apt update &>/dev/null
  eval $INSTALL_DOCKER_CMD
  if [[ $? -eq 0 ]]; then
    v_echo "${GREEN}Docker install successfuly${NC} ..."
  else
    v_echo "${RED}Docker installation end with error${NC} ..."
    v_echo "${RED}Try to run 'sudo bash dockerInstall.deb.sh -rd -rdc' before installation${NC} ..."
    exit 1
  fi

  # Setup log rotation
  v_echo "Setup log rotation $DOCKER_CONF_PATH ... Set max log files $MAX_LOG_FILES with size of $LOG_MAX_SIZE"
  echo -en "{\n  \"log-driver\": \"json-file\",\n  \"log-opts\": {\n    \"max-size\": \"$LOG_MAX_SIZE\",\n    \"max-file\": \"$MAX_LOG_FILES\"\n  }\n}\n" > $DOCKER_CONF_PATH

  # END
  v_echo "${GREEN}Setup complete!${NC} Enable and Restart Docker"
  systemctl enable docker && systemctl restart docker

}

removeDocker() {

  v_echo "${RED}Removing Docker!${NC} ..."

  systemctl stop docker.socket && systemctl stop docker && systemctl disable docker &>/dev/null
  eval $UNINSTALL_DOCKER && apt update &>/dev/null
  #
  # purge all files if something not deleted
  # [[ -d "/etc/docker/" ]] && rm -rf /etc/docker/
  # dkey="/usr/share/keyrings/docker-archive-keyring.gpg"; [[ -f $dkey ]] && rm $dkey
  # dlist="/etc/apt/sources.list.d/docker.list"; [[ -f $dlist ]] && rm $dlist
  # runc="/usr/bin/runc"; [[ -f $runc ]] && rm $runc
  #
  v_echo "${GREEN}Removing complete${NC} ..."

}

removeDockerCompose() {
  v_echo "${RED}Removing Docker Compose!${NC} ..."
  # find Docker Compose and delete it
  [[ -f $DOCKER_COMPOSE_PATH ]] && rm $DOCKER_COMPOSE_PATH || v_echo "Docker compose not found in $DOCKER_COMPOSE_PATH, nothing to delete ..."
}

# checking if option has argument
checkArgument() {
  # checking if argument for option isset. if at the start --, that is new option and arg is not set
  if [[ -z $2 ]] || [[ $2 == --* ]] || [[ $2 == -* ]]; then
    echo -en "${RED}Error!${NC} Argument for option $1 is required\n" 1>&2
    exit 1
  fi
}

# SHOW HELP IF SCRIPT RUN WITHOUT OPTIONS
[[ $OPT_COUNT == 0 ]] && help

# start parsing
while [[ $OPT_POSITION -le $OPT_COUNT ]]; do
  case $1 in
    -h | --help)
      # if position of argument more then 1, means that other options is sets
      if [[ $OPT_POSITION -lt 2 ]]; then
        help
      fi
      ;;
    -ia | --install-all)
      # if position of argument more then 1, means that other options is sets
      ACTION_TODO="ia"
      ;;
    -irp | --install-req-packages)
      # install required packages
      ACTION_TODO="irp"
      ;;
    -id | --install-docker)
      # install docker
      ACTION_TODO="id"
      ;;
    -idc | --install-docker-compose)
      # install docker compose
      ACTION_TODO="idc"
      ;;
    -lf | --log-files)
      checkArgument $1 $2
      if [ $2 -ge 0 ] 2>/dev/null; then
        MAX_LOG_FILES=$2
      else
        echo -en "Argument for $1 ${RED}$2${NC} is not integer\n"
        exit 1
      fi
      ((OPT_POSITION=OPT_POSITION+1)) && shift 1
      ;;
    -ls | --log-size)
      checkArgument $1 $2
      if [ $2 -ge 0 ] 2>/dev/null; then
        LOG_MAX_SIZE=$2"m"
      else
        echo -en "Argument for ${RED}$2${NC} is not integer\n"
        exit 1
      fi
      ((OPT_POSITION=OPT_POSITION+1)) && shift 1
      ;;
    -rd | --remove-docker)
      ACTION_TODO="rd"
      ;;
    -rdc | --remove-docker-compose)
      ACTION_TODO="rdc"
      ;;
    -c | --check)
      checkInstall
      exit 0
      ;;
    -dcv | --docker-compose-version)
      checkArgument $1 $2
      DOCKER_COMPOSE_VERSION=$2
      ((OPT_POSITION=OPT_POSITION+1)) && shift 1
      ;;
    -s | --silent)
      SILENT="1"
      ;;
    * )
      help
      ;;
  esac
  OPT_POSITION=$((OPT_POSITION+1))
  shift 1
done

case $ACTION_TODO in
  ia)
    installReqPackages
    installDocker
    installDockerCompose
    ;;
  irp)
    installReqPackages
    ;;
  id)
    installDocker
    ;;
  idc)
    installDockerCompose
    ;;
  rd)
    removeDocker
    ;;
  rdc)
    removeDockerCompose
    ;;
esac

exit 0
