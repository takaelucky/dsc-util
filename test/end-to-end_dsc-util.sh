#!/bin/bash

DSC_UTIL="./dsc-util.sh"
LOG="/tmp/dsc-util-tests.log"
>$LOG

check_login()
{
  # exit out the script if not login to registry.redhat.io
  timeout --foreground -k 1 5 podman login registry.redhat.io > /dev/null 2>&1
  if [ $? != 0 ]; then
    echo "Please login registry.redhat.io before running this script."
    echo "command is 'podman login registry.redhat.io' to login"
    exit 1
  fi
}

discovery_current_state()
{
  mkdir -pv "${HOME}"/.local/share/discovery/data
  mkdir -pv "${HOME}"/.local/share/discovery/log
  mkdir -pv "${HOME}"/.local/share/discovery/sshkeys
  
  podman pull registry.redhat.io/rhel8/postgresql-12:latest
  podman pull registry.redhat.io/discovery/discovery-server-rhel9:latest
  
  podman run --name dsc-db \
  --pod new:discovery-pod \
  --publish 9443:443 \
  --restart on-failure \
  -e POSTGRESQL_USER=dsc \
  -e POSTGRESQL_PASSWORD=server_administrator_password \
  -e POSTGRESQL_DATABASE=dsc-db \
  -v dsc-data:/var/lib/pgsql/data \
  -d registry.redhat.io/rhel8/postgresql-12:latest
  
  podman run \
  --name discovery \
  --restart on-failure \
  --pod discovery-pod \
  -e DJANGO_DEBUG=False \
  -e NETWORK_CONNECT_JOB_TIMEOUT=60 \
  -e NETWORK_INSPECT_JOB_TIMEOUT=600 \
  -e PRODUCTION=True \
  -e QPC_DBMS_HOST=localhost \
  -e QPC_DBMS_PASSWORD=server_administrator_password \
  -e QPC_DBMS_USER=dsc \
  -e QPC_DBMS_DATABASE=dsc-db \
  -e QPC_SERVER_PASSWORD=server_administrator_password \
  -e QPC_SERVER_TIMEOUT=120 \
  -e QPC_SERVER_USERNAME=admin \
  -e QPC_SERVER_USER_EMAIL=admin@example.com \
  -v "${HOME}"/.local/share/discovery/data/:/var/data:z \
  -v "${HOME}"/.local/share/discovery/log/:/var/log:z \
  -v "${HOME}"/.local/share/discovery/sshkeys/:/sshkeys:z \
  -d registry.redhat.io/discovery/discovery-server-rhel9:latest

  # Now, it's time to call all the amazing tests
  dsc_tests
}

discovery_previous_state()
{
  # Discovery version 1.4.6
  # added _123 to the password, once it was failing during the update
  
  mkdir -p "${HOME}"/.local/share/discovery/data
  mkdir -p "${HOME}"/.local/share/discovery/log
  mkdir -p "${HOME}"/.local/share/discovery/sshkeys
  
  podman pull registry.redhat.io/rhel8/postgresql-12:latest
  podman pull registry.redhat.io/discovery/discovery-server-rhel9:1.4.6
  
  podman run --name dsc-db \
  --pod new:discovery-pod \
  --publish 9443:443 \
  --restart on-failure \
  -e POSTGRESQL_USER=dsc \
  -e POSTGRESQL_PASSWORD=server_administrator_password_123 \
  -e POSTGRESQL_DATABASE=dsc-db \
  -v dsc-data:/var/lib/pgsql/data \
  -d registry.redhat.io/rhel8/postgresql-12:latest
  
  podman run \
  --name discovery \
  --restart on-failure \
  --pod discovery-pod \
  -e DJANGO_DEBUG=False \
  -e NETWORK_CONNECT_JOB_TIMEOUT=60 \
  -e NETWORK_INSPECT_JOB_TIMEOUT=600 \
  -e PRODUCTION=True \
  -e QPC_DBMS_HOST=localhost \
  -e QPC_DBMS_PASSWORD=server_administrator_password_123 \
  -e QPC_DBMS_USER=dsc \
  -e QPC_DBMS_DATABASE=dsc-db \
  -e QPC_SERVER_PASSWORD=server_administrator_password_123 \
  -e QPC_SERVER_TIMEOUT=120 \
  -e QPC_SERVER_USERNAME=admin \
  -e QPC_SERVER_USER_EMAIL=admin@example.com \
  -v "${HOME}"/.local/share/discovery/data/:/var/data:z \
  -v "${HOME}"/.local/share/discovery/log/:/var/log:z \
  -v "${HOME}"/.local/share/discovery/sshkeys/:/sshkeys:z \
  -d registry.redhat.io/discovery/discovery-server-rhel9:1.4.6

  dsc_tests
}

discovery_old_version_diff_path()
{
  # Discovery version 1.4.4
  # added _123 to the password, once it was failing during the update
  
  mkdir -pv /var/discovery/server/volumes/data
  mkdir -pv /var/discovery/server/volumes/log
  mkdir -pv /var/discovery/server/volumes/sshkeys
  
  podman pull registry.redhat.io/rhel8/postgresql-12:latest
  podman pull registry.redhat.io/discovery/discovery-server-rhel9:1.4.4
  
  podman run --name dsc-db \
  --pod new:discovery-pod \
  --publish 9443:443 \
  --restart on-failure \
  -e POSTGRESQL_USER=dsc \
  -e POSTGRESQL_PASSWORD=server_administrator_password_123 \
  -e POSTGRESQL_DATABASE=dsc-db \
  -v dsc-data:/var/lib/pgsql/data \
  -d registry.redhat.io/rhel8/postgresql-12:latest
  
  podman run \
  --name discovery \
  --restart on-failure \
  --pod discovery-pod \
  -e DJANGO_DEBUG=False \
  -e NETWORK_CONNECT_JOB_TIMEOUT=60 \
  -e NETWORK_INSPECT_JOB_TIMEOUT=600 \
  -e PRODUCTION=True \
  -e QPC_DBMS_HOST=localhost \
  -e QPC_DBMS_PASSWORD=server_administrator_password \
  -e QPC_DBMS_USER=dsc \
  -e QPC_DBMS_DATABASE=dsc-db \
  -e QPC_SERVER_PASSWORD=server_administrator_password \
  -e QPC_SERVER_TIMEOUT=120 \
  -e QPC_SERVER_USERNAME=admin \
  -e QPC_SERVER_USER_EMAIL=admin@example.com \
  -v /var/discovery/server/volumes/data/:/var/data:z \
  -v /var/discovery/server/volumes/log/:/var/log:z \
  -v /var/discovery/server/volumes/sshkeys/:/sshkeys:z \
  -d registry.redhat.io/discovery/discovery-server-rhel9:1.4.4

  dsc_tests
}

discovery_not_installed()
{
  echo "$(date)" &>>$LOG
  echo "stopping the pod" &>>$LOG
  echo "---" &>>$LOG
  podman pod stop discovery-pod &>>$LOG
  echo "---" &>>$LOG
  echo &>>$LOG

  echo "$(date)" &>>$LOG
  echo "removing the 'discovery-pod' pod" &>>$LOG
  echo "---" &>>$LOG
  podman pod rm discovery-pod &>>$LOG
  echo "---" &>>$LOG
  echo &>>$LOG

  echo "$(date)" &>>$LOG
  echo "removing the volume" &>>$LOG
  echo "---" &>>$LOG
  podman volume rm dsc-data &>>$LOG
  echo "---" &>>$LOG
  echo &>>$LOG

  echo "$(date)" &>>$LOG
  echo "removing images" &>>$LOG
  echo "---" &>>$LOG
  podman image rm registry.redhat.io/rhel8/postgresql-12 &>>$LOG
  podman image rm registry.redhat.io/discovery/discovery-server-rhel9 &>>$LOG
  podman image rm registry.redhat.io/discovery/discovery-server-rhel9:1.4.6 &>>$LOG
  podman image rm registry.redhat.io/discovery/discovery-server-rhel9:1.4.4 &>>$LOG
  echo "---" &>>$LOG
  echo &>>$LOG
  
  echo "$(date)" &>>$LOG
  echo "removing the '$HOME/.local/share/discovery' folder, if around" &>>$LOG
  echo "---" &>>$LOG
  if [ -d $HOME/.local/share/discovery ]; then
    echo "removing the directory '$HOME/.local/share/discovery'" &>>$LOG
    rm -rfv "$HOME/.local/share/discovery" &>>$LOG
  fi
  echo "---" &>>$LOG
  echo &>>$LOG

  echo "$(date)" &>>$LOG
  echo "removing the '/var/discovery' folder, if around" &>>$LOG
  echo "---" &>>$LOG
  if [ -d /var/discovery ]; then
    echo "removing the directory '/var/discovery'" &>>$LOG
    rm -rfv "/var/discovery" &>>$LOG
  fi
  echo "---" &>>$LOG
  echo &>>$LOG
}

####

dsc_tests()
{
  check_fresh=$1

  echo
  echo "## BEGINNING TEST ##"

  echo
  echo "waiting for 10 seconds ..., please, bare with me ..."
  sleep 10

  echo
  echo "check-version"
  echo "---"
  $DSC_UTIL check-version         # Check the current version and also for update
  echo "---"

  echo
  echo "stop-pod"
  echo "---"
  $DSC_UTIL stop-pod              # Stop the 'discovery-pod' pod
  echo "---"

  echo
  echo "start-pod"
  echo "---"
  $DSC_UTIL start-pod             # Start the 'discovery-pod' pod
  echo "---"

  echo
  echo "waiting for 5 seconds ..., please, bare with me ..."
  sleep 5

  echo
  echo "get-logs"
  echo "---"
  $DSC_UTIL get-logs              # Get the logs from discovery and DB
  echo "---"

  echo
  echo "do-update"
  echo "---"
  echo "c" | $DSC_UTIL do-update             # Update the discovery tool to the latest
  echo "---"

  echo
  echo "do-install"
  echo "---"
  if [ $check_fresh == "fresh" ]; then
    echo "## NOT AUTOMATED AT THIS MOMENT"
    echo "Please, run $DSC_UTIL do-install manually, once it will request a new password"
    echo "## NOT AUTOMATED AT THIS MOMENT"
  else
    $DSC_UTIL do-install            # Fresh installation of the Discovery tool
  fi
  echo "---"

  echo
  echo "podman ps -a"
  echo "---"
  podman ps -a
  echo "---"

  echo
  echo "podman images"
  echo "---"
  podman images
  echo "---"

  # not tested at this moment
  # $DSC_UTIL check-version-disc    # Check the current version and also for update, on disconnected environment
  # $DSC_UTIL do-chpass-update      # Change password and update the discovery tool to the latest

  echo
  echo "## ENDING TEST ##"
}


# To confirm that I'm using an account with access to registry.redhat.io
check_login

echo "# --- Scenario 1 ---"
echo "# Total discovery cleanup on the local machine"
discovery_not_installed

echo "# Discovery on the latest version"
discovery_current_state
echo "# --- End of Scenario 1 ---"


echo "# --- Scenario 2 ---"
echo "# Total discovery cleanup on the local machine"
discovery_not_installed

echo "# Discovery on version 1.4.6"
discovery_previous_state
echo "# --- End of Scenario 2 ---"


echo "# --- Scenario 3 ---"
echo "# Total discovery cleanup on the local machine"
discovery_not_installed

echo "# Discovery on version 1.4.4 and diff path for the files"
discovery_old_version_diff_path
echo "# --- End of Scenario 3 ---"


echo "# --- Scenario 4 ---"
echo "# Total discovery cleanup on the local machine"
echo "# and let's install using the dsc-util"
discovery_not_installed

echo "# Testing all the options in a fresh environment"
dsc_tests fresh
echo "# --- End of Scenario 4 ---"
