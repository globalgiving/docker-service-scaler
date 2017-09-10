#!/bin/bash - 

DATA="$(aws dynamodb scan --region "${AWS_REGION}" --table-name "${DYNAMODB_TABLE}")"
for I in `echo ${DATA} | jq -rc '.Items[] | {name: .name.S, replicas: .replicas.N, mounts: [.mounts.L[] | .S], mode: .mode.S, image: .image.S, networks: [.networks.L[] | .S], ports: [.ports.L[] | .S], memory: .memory.N, cpu: .cpu.N, constraint: .constraint.S, image_private: .image_private.BOOL | tostring}'`;
do
  SERVICE_NAME="$(echo "$I" | jq -r '.name')"
  SERVICE_REPLICAS="$(echo "$I" | jq -r '.replicas')"
  EXISTS=$(docker service ls --filter "name=${SERVICE_NAME}" --format "{{.ID}}" | wc -l)
  if [[ "${EXISTS}" = "0" ]]
  then
    SERVICE_NETWORKS="$(echo "$I" | jq -r '.networks[]')"
    SERVICE_CONSTRAINT="$(echo "$I" | jq -r '.constraint')"
    SERVICE_IMAGE="$(echo "$I" | jq -r '.image')"
    SERVICE_IMAGE_PRIVATE="$(echo "$I" | jq -r '.image_private')"
    SERVICE_MODE="$(echo "$I" | jq -r '.mode')"
    SERVICE_MOUNTS="$(echo "$I" | jq -r '.mounts[]')"
    SERVICE_PORTS="$(echo "$I" | jq -r '.ports[]')"
    SERVICE_CPU="$(echo "$I" | jq -r '.cpu')"
    SERVICE_MEMORY="$(echo "$I" | jq -r '.memory')"
    PUBLISH=""
    REGISTRY_AUTH=""
    RESERVE_MEMORY=""
    RESERVE_CPU=""
    CONSTRAINT=""
    NETWORKS=""
    MOUNTS=""

    for M in `echo ${SERVICE_MOUNTS}`;
    do
      MOUNTS="--mount $M ${MOUNTS}"
    done

    for P in `echo ${SERVICE_PORTS}`;
    do
      PUBLISH="--publish $P ${PUBLISH}"
    done

    for N in `echo ${SERVICE_NETWORKS}`;
    do
      NETWORKS="--network $N ${NETWORKS}"
    done

    if [[ "${SERVICE_IMAGE_PRIVATE}" == "true" ]]
    then
      REGISTRY_AUTH="--with-registry-auth"
    fi

    if ! [[ "${SERVICE_MEMORY}" = "0" ]]
    then
      RESERVE_MEMORY="--reserve-memory ${SERVICE_MEMORY}"
    fi

    if ! [[ "${SERVICE_CPU}" = "0" ]]
    then
      RESERVE_CPU="--reserve-cpu ${SERVICE_CPU}"
    fi

    if ! [[ "${SERVICE_CONSTRAINT}" = "none" ]]
    then
      CONSTRAINT="--constraint ${SERVICE_CONSTRAINT}"
    fi

    echo "Creating ${SERVICE_NAME}"
    docker service create --name "${SERVICE_NAME}" --replicas "${SERVICE_REPLICAS}" ${RESERVE_MEMORY} ${RESERVE_CPU} ${CONSTRAINT} --placement-pref 'spread=engine.labels.availability_zone' --mode "${SERVICE_MODE}" ${MOUNTS} ${PUBLISH} ${NETWORKS} ${REGISTRY_AUTH} ${SERVICE_IMAGE}
  else
    docker service scale "${SERVICE_NAME}=${SERVICE_REPLICAS}"
  fi
done

# TODO: docker service inspect NAME | jq -r '.[] | .Spec | {name: .Name, replicas: .Mode.Replicated.Replicas, mount: .sdf, mode: .Mode | keys[] | ascii_downcase, image: .TaskTemplate.ContainerSpec.Image | split("@")[0]}'
