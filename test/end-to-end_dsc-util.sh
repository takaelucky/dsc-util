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


# To confirm that I'm using an account with access to registry.redhat.io
check_login

# --- Scenario 1 ---
# Total discovery cleanup on the local machine
discovery_not_installed

# Discovery on the latest version
discovery_current_state
# --- End of Scenario 1 ---


# --- Scenario 2 ---
# Total discovery cleanup on the local machine
# discovery_not_installed

# Discovery on version 1.4.6
# discovery_previous_state
# --- End of Scenario 2 ---


# --- Scenario 3 ---
# Total discovery cleanup on the local machine
# discovery_not_installed

# Discovery on version 1.4.4 and diff path for the files
# discovery_old_version_diff_path
# --- End of Scenario 3 ---
