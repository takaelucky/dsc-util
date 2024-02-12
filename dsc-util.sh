#!/bin/bash

### Global Variable ###
LATEST_IMAGE=discovery-server-rhel9
REG_PATH=registry.redhat.io/discovery
CURRENT_VER=""
LATEST_VER=""
### End of Global Variable ###

### Function declaration ### 

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
    echo "Please update your disvocery tool to the latest by using https://access.redhat.com/articles/7036146"
  else
    echo "Your current version is $CURRENT_VER and the latest is $LATEST_VER"
    echo "The Discovery tool is up-to-date."
  fi

}

### End of Function declaration ### 

###  Main ###

check_login
get_current_ver
get_latest_ver
check_current


