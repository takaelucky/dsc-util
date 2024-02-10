#!/bin/bash

### Global Variable ###
LATEST_IMAGE=discovery-server-rhel9
REG_PATH=registry.redhat.io/discovery
CURRENT_VER=""
LATEST_VER=""
### End of Global Variable ###

### Function declaration ### 

check_login(){
 echo "Please login registry.redhat.io before running this script"
 echo "If you already logged in type 'c' to continue or 'x' to exit"
 read CONTINUE

 case $CONTINUE in 
   c|C) 
       if (! podman search $REG_PATH/$LATEST_IMAGE --list-tags > /dev/null 2>&1 )
       then
         echo "You will need to login registry.redhat.io before running this script"
         exit 1
       fi
       ;;
   x|X) 
       exit ;;
   *)
       echo "Invalid input. exiting..." 
       exit ;;
 esac
}

get_current_ver(){

  if [ `podman ps -a | grep discovery | grep -v toolbox | wc -l` -eq 0 ]
  then
     echo "Discovery container does not exist. Please start the container or install it before using the script"
     exit 1;
  fi
  CURRENT_VER=$(podman inspect discovery -f '{{.Config.Labels.version}}')
}

get_latest_ver(){

  LATEST_VER=`podman search $REG_PATH/$LATEST_IMAGE --list-tags | cut -d" " -f3 | sort -rn | head -n1 | cut -d"-" -f1`
  if [ $? != 0 ]
  then
    echo "You need to login to registry.redhat.io before running this script"
    exit 1; 
  fi
  #echo $LATEST_VER
  #echo $CURRENT_VER
}

check_current(){
  if [ `podman images | grep $LATEST_IMAGE | wc -l` -eq 0 ] 
  then 
    echo "Please update your disvocery tool to the latest by using https://access.redhat.com/solutions/7025846"
  elif [ $LATEST_VER = $CURRENT_VER ]
  then
    echo "You are up-to-date"
  else
    echo "Please update your disvocery tool to the latest by using https://access.redhat.com/solutions/7025846"
  fi

}

### End of Function declaration ### 

###  Main ###

check_login
get_current_ver
get_latest_ver
check_current


