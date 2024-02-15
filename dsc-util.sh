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
CURRENT_VER=""
LATEST_VER=""
### End of Global Variable ###

### Function declaration ### 

main_menu()
{
  case $1 in
    check_version)
      #echo "checking"
      check_login
      get_current_ver
      get_latest_ver
      check_current
      ;;
    stop-pod)
      echo "Stopping the discovery-pod pod"
      podman pod stop discovery-pod
      podman ps -p
      ;;
    start-pod)
      echo "Starting the discovery-pod pod"
      podman pod start discovery-pod
      podman ps -p
      ;;
    get-logs)
      get_logs_func
      ;;
    *)
      echo "Please, pass the desired parameter"
      echo ""
      echo "$0 check_version    # Check the current version and also for update"
      echo "$0 stop-pod         # Stop the 'discovery-pod' pod"
      echo "$0 start-pod        # Start the 'discovery-pod' pod"
      echo "$0 get-logs         # Get the logs from discovery and DB"
      ;;
  esac
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
  # exit out if dsc server and db does not exist
  if [ `podman ps -a | grep discovery | grep -v toolbox | wc -l` -eq 0 ] && [ `podman ps -a | grep dsc-db | wc -l` -eq 0 ]
  then
     echo "Discovery server and DB does not exist or was never installed."
     echo "Please use https://access.redhat.com/documentation/en-us/subscription_central/1-latest/html-single/installing_and_configuring_discovery/index to install the latest version"
     exit 1;
  elif [ `podman ps -a | grep discovery | grep -v toolbox | wc -l` -eq 0 ]; then
     echo "Discovery server does not exist."
     echo "Please update your discovery tool to the latest by using https://access.redhat.com/articles/7036146"
     exit 1; 
  fi
  CURRENT_VER=$(podman inspect discovery -f '{{.Config.Labels.version}}')
}

get_latest_ver(){
   
  if ( ! podman search $REG_PATH/$LATEST_IMAGE --list-tags > /dev/null 2>&1 )
  then
    echo "Command 'podman search $REG_PATH/$LATEST_IMAGE --list-tags' is erroring"
    echo "Possibly there is an outage on Red Hat side. Please check https://status.redhat.com/ or try the script later"
    exit 1; 
  fi
  LATEST_VER=`podman search $REG_PATH/$LATEST_IMAGE --list-tags | cut -d" " -f3 | sort -rn | head -n1 | cut -d"-" -f1`
}

check_current(){
  if [ `podman images | grep $LATEST_IMAGE | wc -l` -eq 0 ] || [ $LATEST_VER != $CURRENT_VER ]
  then 
    echo "Your current version is $CURRENT_VER and the latest is $LATEST_VER"
    echo "Please update your discovery tool to the latest by using https://access.redhat.com/articles/7036146"
  else
    echo "Your current version is $CURRENT_VER and the latest is $LATEST_VER"
    echo "The Discovery tool is up-to-date."
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
  while [ $i -le 1 ]
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


### End of Function declaration ### 

###  Main ###

main_menu $1
#check_login
#get_current_ver
#get_latest_ver
#check_current
