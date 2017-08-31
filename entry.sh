#!/bin/sh

# set system wide env variables, so they are available to ssh connections
/usr/bin/env > /etc/environment

echo "Initialize logging for scaler daemon"
# setup symlink to output logs from relevant scripts to container logs
ln -s /proc/1/fd/1 /var/log/docker/scaler.log

echo "Logging into DockerHub"
source /run/secrets/dockerhub
docker login -u "${DOCKERHUB_USER}" -p "${DOCKERHUB_PASS}"

# start cron
/usr/sbin/crond -f -l 9 -L /var/log/cron.log

