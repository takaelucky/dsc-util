#!/bin/bash

# 
# License ....: GPLv3
# Purpose ....: Help with some pending features on discovery tool
# Upstream ...: https://github.com/Qikfix/dsc-util
# Developer ..: Takae Harrington <takae@takaeharrington.com>
#               Waldirio Pinheiro <waldirio@gmail.com>
# 

### Global Variable ###
LATEST_IMAGE=discovery-server-rhel9
REG_PATH=registry.redhat.io/discovery
LATEST_PSQL_IMAGE=registry.redhat.io/rhel8/postgresql-12:latest
HOST_MOUNT_DIR="${HOME}"/.local/share/discovery
CURRENT_VER=""
LATEST_VER=""
DISCOVERY_OFFLINE_FILE="/root/discovery_tags.txt"
CURRENT_PASS=""
NEW_PASS=""
### End of Global Variable ###

### Function declaration ### 

main_menu()
{
  case $1 in
    check_version)
      pre_check
      check_login
      get_current_ver
      get_latest_ver
      check_current
      ;;
    check_version_disc)
      pre_check
      get_current_ver
      get_latest_ver disconnected
      check_current
      ;;
    stop-pod)
      pre_check
      echo "Stopping the discovery-pod pod"
      podman pod stop discovery-pod
      podman ps -p
      ;;
    start-pod)
      pre_check
      echo "Starting the discovery-pod pod"
      podman pod start discovery-pod
      podman ps -p
      ;;
    get-logs)
      pre_check
      get_logs_func
      ;;
    do-update)
      pre_check no_exit
      check_login
      get_current_ver
      get_latest_ver
      check_current no_message
      check_passwd
      pull_latest 
      do_install_func
      ;;
    do-chpass-update|do-install)
      pre_check no_exit
      check_login
      set_passwd
      pull_latest
      do_install_func
      ;;
    *)
      echo "Please, pass the desired parameter"
      echo ""
      echo "$0 check_version         # Check the current version and also for update"
      echo "$0 check_version_disc    # Check the current version and also for update, on disconnected environment"
      echo "$0 stop-pod              # Stop the 'discovery-pod' pod"
      echo "$0 start-pod             # Start the 'discovery-pod' pod"
      echo "$0 get-logs              # Get the logs from discovery and DB"
      echo "$0 do-update             # Update the discovery tool to the latest"
      echo "$0 do-chpass-update      # Change password and update the discovery tool to the latest"
      echo "$0 do-install            # Fresh installation of the Discovery tool"
      ;;
  esac
}

pre_check(){
  # exit out if podman is not installed
  which podman > /dev/null 2>&1
  if [ $? = 1 ]
  then
    echo "podman is not installed.  Please enable BaseOS and AppStream repo"
    echo "and execute 'dnf install podman'"
    exit 1
  fi

  # exit out if discovery server and/or db does not exist, but bypass if this is called from do-update/do-install
  if [[ -z $1 ]]
  then
    if [ `podman ps -a | grep discovery | grep -v toolbox | wc -l` -eq 0 ] || [ `podman ps -a | grep dsc-db | wc -l` -eq 0 ]
    then
      echo "Discovery and/or DB containers does not exist or were never installed."
      echo "Please install the discovery tool by using"
      echo "https://access.redhat.com/documentation/en-us/subscription_central/1-latest/html-single/installing_and_configuring_discovery/index to install the latest version"
      echo "Or run './dsc-util.sh do-install' to reinstall the Discovery tools" 
      exit 1
    fi
  fi
}

check_login(){
  # exit out the script if not login to registry.redhat.io
  timeout --foreground -k 1 5 podman login registry.redhat.io > /dev/null 2>&1 
  if [ $? != 0 ] 
  then
    echo "Please login registry.redhat.io before running this script."
    echo "command is 'podman login registry.redhat.io' to login"
    exit 1
  fi
}

get_current_ver(){
  CURRENT_VER=$(podman inspect discovery -f '{{.Config.Labels.version}}')
  #echo "current version is $CURRENT_VER"
}

get_latest_ver(){
  
  if [ "$1" == "" ]; then
    echo "connected environment"
    echo
    if ( ! podman search $REG_PATH/$LATEST_IMAGE --list-tags > /dev/null 2>&1 )
    then
      echo "Command 'podman search $REG_PATH/$LATEST_IMAGE --list-tags' is erroring"
      echo "Possibly there is an outage on Red Hat side. Please check https://status.redhat.com/ or try the script later"
      exit 1; 
    fi
    LATEST_VER=`podman search $REG_PATH/$LATEST_IMAGE --list-tags | cut -d" " -f3 | sort -rn | head -n1 | cut -d"-" -f1`
  else
    echo "disconnected environment"
    echo
    echo "On any connected RHEL, please proceed as below"
    echo "podman login registry.redhat.io"
    echo "podman search registry.redhat.io/discovery/discovery-server-rhel9 --list-tags >/tmp/discovery_tags.txt"
    echo
    echo "once you get the file created, copy and save this file on the discovery server as '$DISCOVERY_OFFLINE_FILE'"
    echo
    echo -n "Do you have already the file '$DISCOVERY_OFFLINE_FILE'? (y/n) "
    read answer
    case $answer in
      y|Y)
	if [ -f $DISCOVERY_OFFLINE_FILE ]; then
          LATEST_VER=`cat $DISCOVERY_OFFLINE_FILE | cut -d" " -f3 | sort -rn | head -n1 | cut -d"-" -f1`
        else
          echo "The file '$DISCOVERY_OFFLINE_FILE' is not present"
	  exit 1
	fi
        ;;
      n|N)
        echo "Please, execute the steps above and try again."
	exit 1
        ;;
      *)
        echo "Invalid option."
	exit 1
        ;;
    esac

  fi
}

check_current(){
  if [ `podman images | grep $LATEST_IMAGE | wc -l` -eq 0 ] || [ $LATEST_VER != $CURRENT_VER ]
  then
    if [[ -z $1 ]]
    then
     echo "Your current version is $CURRENT_VER and the latest is $LATEST_VER"
     echo "Please run './dsc-util.sh do-update' to update to the latest"
     echo "ref: https://access.redhat.com/articles/7036146"
    fi
  else
    echo "Your current version is $CURRENT_VER and the latest is $LATEST_VER"
    echo "The Discovery tool is up-to-date and you are all set"
    exit
  fi

}

get_logs_func(){
  # get the logs from host mount for the disvocery and dsc-db
 
  # remove previous file if exist
  if [ -e /tmp/dsctool_* ]
  then
    rm -f /tmp/dsctool_*
  fi
 
  # getting host mount from the discovery & dsc-db container
  declare -a HOST_MOUNT
  i=0
  while [ $i -le 2 ]
  do
  HOST_MOUNT[$i]=`podman inspect discovery --format="{{ (index .Mounts $i).Source}}"`
  i=$(( $i + 1 ))
  done 
 
  HOST_MOUNT[$i]=`podman inspect dsc-db --format="{{ (index .Mounts 0).Source}}"` 
  # echo ${HOST_MOUNT[@]}
  tar -czvf /tmp/dsctool_`date +"%m%d%Y"`.tar.gz ${HOST_MOUNT[@]} &> /dev/null
  if [ $? -ne 0 ] || [ ! -e /tmp/dsctool_* ]
  then
    echo "There is a problem and the log file did not get created" 
    echo "Please run the command manually to observe the error"
    echo "Command: 'tar -czvf /tmp/dsctool_`date +"%m%d%Y"`.tar.gz ${HOST_MOUNT[@]}'"
  else
    echo "Please attach the log file:  /tmp/dsctool_`date +"%m%d%Y"`.tar.gz"
  fi
}

check_passwd(){
  # check and notify the strick passwort requirement
  # the below 2 lines are for future enhancement if allows for different password
  # CURRENT_PSQL_PASS=`podman inspect dsc-db -f "{{ (index .Config.Env 2) }}" | cut -d"=" -f2`
  # CURRENT_DBMS_PASS=`podman inspect discovery -f "{{ (index .Config.Env 18) }}" | cut -d"=" -f2`

  USER_REPLY=""

  passwd_requirement

  read -p "If your current password does not meet the above, please type 'q' to quit or 'c' to continue: " USER_REPLY

  case $USER_REPLY in 
	q|Q) 
           echo "Run ./dsc-util.sh do-chpass-update to change the password and get the latest"
           exit 1
   	   ;;
        c|C)
           ;;
        *)
           echo "Invalid repsonse" 
           echo
           check_passwd
           ;;
  esac
 
  CURRENT_PASS=`podman inspect discovery -f "{{ (index .Config.Env 22) }}" | cut -d"=" -f2`  
  #echo ${#CURRENT_PASS}

  if [ ${#CURRENT_PASS} -lt 10 ]
  then
     echo "Your current password length is less than 10"
     echo "Run ./dsc-util.sh do-chpass-update to change the password and get the latest"
     exit 1
  fi

}

passwd_requirement(){
  #  notify the password requirement
  echo
  echo "The server admin password requiremt has changed as below:"
  echo
  echo "- at least ten characters"
  echo "- cannot be a word found in the dictionary"
  echo "- cannot be the previously provided Discovery default passwords"
  echo "- cannot be numeric only"
  echo
  echo "*** this script will only check the length of the password ***" 
  echo "*** Any missing requirement causes the upgrade/installation failure ***" 
  echo
}

set_passwd(){
  # set password for the upgrade and the installation

  passwd_requirement
  read -sp "Please type the new admin password:  " NEW_PASS
  echo
  read -sp "Please re-type the new admin password: " CONFIRM_PASS

  if [[ "$NEW_PASS" != "$CONFIRM_PASS" ]]
  then
    echo 
    echo "FAIL: Password does not match - Try again"
    exit 1  
  fi

  if [ ${#NEW_PASS} -lt 10 ]
  then
    echo
    echo "FAIL: The password does not meet the requirement of minimum 10 characters - Try again" 
    exit 1 
  fi
}

pull_latest(){
  # download the latest images
  echo   
  podman pull $REG_PATH/$LATEST_IMAGE
  podman pull $LATEST_PSQL_IMAGE

}

do_install_func(){
  # actual upgrade or installation will happen here
  # check existing host mount
  CURRENT_MOUNT_DIR=`podman inspect discovery  --format="{{ (index .Mounts 0).Source}}" | cut -d"/" -f1,2,3,4,5`

  echo  
  echo "Starting..." 

  # stop discovery-pod and remove discovery container
  podman pod stop discovery-pod
  podman rm discovery

  # set current password to a new one if user wants to change, then clean & re-run dsc-db with the new password
  if [[ -n $NEW_PASS ]]
  then
    CURRENT_PASS=$NEW_PASS
    podman rm dsc-db
    podman pod rm discovery-pod
    podman run --name dsc-db \
    --pod new:discovery-pod \
    --publish 9443:443 \
    --restart on-failure \
    -e POSTGRESQL_USER=dsc \
    -e POSTGRESQL_PASSWORD=$CURRENT_PASS \
    -e POSTGRESQL_DATABASE=dsc-db \
    -v dsc-data:/var/lib/pgsql/data \
    -d $LATEST_PSQL_IMAGE 
  fi

  if [[ ! -d $HOST_MOUNT_DIR/data ]] || [[ ! -d $HOST_MOUNT_DIR/log ]] || [[ ! -d $HOST_MOUNT_DIR/sshkeys ]]
  then
    mkdir -p $HOST_MOUNT_DIR/data
    mkdir -p $HOST_MOUNT_DIR/log
    mkdir -p $HOST_MOUNT_DIR/sshkeys
  fi

  #echo $CURRENT_MOUNT_DIR

  if [[ $CURRENT_MOUNT_DIR != $HOST_MOUNT_DIR ]]
  then
    cp -r $CURRENT_MOUNT_DIR/* $HOST_MOUNT_DIR/
  fi

  # re-run discovery with the specified password
  podman run \
  --name discovery \
  --restart on-failure \
  --pod discovery-pod \
  --label "io.containers.autoupdate=registry" \
  -e DJANGO_DEBUG=False \
  -e NETWORK_CONNECT_JOB_TIMEOUT=60 \
  -e NETWORK_INSPECT_JOB_TIMEOUT=600 \
  -e PRODUCTION=True \
  -e QPC_DBMS_HOST=localhost \
  -e QPC_DBMS_PASSWORD=$CURRENT_PASS \
  -e QPC_DBMS_USER=dsc \
  -e QPC_DBMS_DATABASE=dsc-db \
  -e QPC_SERVER_PASSWORD=$CURRENT_PASS \
  -e QPC_SERVER_TIMEOUT=120 \
  -e QPC_SERVER_USERNAME=admin \
  -e QPC_SERVER_USER_EMAIL=admin@example.com \
  -v $HOST_MOUNT_DIR/data/:/var/data:z \
  -v $HOST_MOUNT_DIR/log/:/var/log:z \
  -v $HOST_MOUNT_DIR/sshkeys/:/sshkeys:z \
  -d $REG_PATH/$LATEST_IMAGE

  # restating the discovery pod 
  podman pod restart discovery-pod

  sleep 5

  # check if the container started successfully.
 
  if [ `podman ps | grep discovery | wc -l` -eq 0 ] 
  then
    echo "Discovery container did not start, please check the log by 'podman logs discovery' for any errors"
  elif [ `podman ps | grep dsc-db | wc -l` -eq 0 ]
  then
    echo "Discovery database did not start, please check the log by 'podman logs dsc-db' for any errors"
  else
    echo "Discovery tool is up-to-date. Please login the web ui with 'https://ip_discovery:9443' " 
  fi

}

### End of Function declaration ### 

###  Main ###

main_menu $1
