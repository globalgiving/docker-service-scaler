#!/bin/bash - 

DATA="$(aws dynamodb scan --region "${AWS_REGION}" --table-name "${DYNAMODB_TABLE}")"
for I in `echo ${DATA} | jq -rc '.Items[] | {name: .name.S, replicas: .replicas.N, mount: .mount.S, mode: .mode.S, image: .image.S, network: .network.S, ports: .ports.S | split(",")}'`;
do
  SERVICE_NAME="$(echo "$I" | jq -r '.name')"
  SERVICE_REPLICAS="$(echo "$I" | jq -r '.replicas')"
  EXISTS=$(docker service ls --filter "name=${SERVICE_NAME}" --format "{{.ID}}" | wc -l)
  if [[ "${EXISTS}" = "0" ]]
  then
    SERVICE_NETWORK="$(echo "$I" | jq -r '.network')"
    SERVICE_IMAGE="$(echo "$I" | jq -r '.image')"
    SERVICE_MODE="$(echo "$I" | jq -r '.mode')"
    SERVICE_MOUNT="$(echo "$I" | jq -r '.mount')"
    SERVICE_PORTS="$(echo "$I" | jq -r '.ports[]')"
    PUBLISH=""
    if [[ "${SERVICE_MOUNT}" = "none" ]]
    then
      SERVICE_MOUNT=""
    else
      SERVICE_MOUNT="--mount ${SERVICE_MOUNT}"
    fi
    if [[ "${SERVICE_PORTS}" = "none" ]]
    then
      PUBLISH=""
    else
      for P in `echo ${SERVICE_PORTS}`;
      do
        PUBLISH="--publish $P ${PUBLISH}"
      done
    fi
    echo "Creating ${SERVICE_NAME}"
    docker service create --name "${SERVICE_NAME}" --replicas "${SERVICE_REPLICAS}" --constraint "engine.labels.network==${SERVICE_NETWORK}" --placement-pref 'spread=engine.labels.availability_zone' --mode "${SERVICE_MODE}" ${SERVICE_MOUNT} ${PUBLISH} ${SERVICE_IMAGE}
  else
    docker service scale "${SERVICE_NAME}=${SERVICE_REPLICAS}"
  fi
done
