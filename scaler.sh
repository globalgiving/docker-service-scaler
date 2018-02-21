#!/bin/bash - 

DATA="$(aws dynamodb scan --region "${AWS_REGION}" --table-name "${DYNAMODB_TABLE}")"
PARSED=$(echo "${DATA}" | jq -rc '.Items[] | {name: .name.S, replicas: .replicas.N, env: [.env.L[] | .S], mounts: [.mounts.L[] | .S], mode: .mode.S, image: .image.S, secrets: [.secrets.L[] | .S], clabels: (.container_labels.M // {}) | to_entries | map_values(. = .key + "='" + .value.S + "'"), health_cmd: (.health_cmd.S // "none"), log_driver: .log_driver.S, log_opt: [.log_opt.L[] | .S], networks: [.networks.L[] | .S], ports: [.ports.L[] | .S], hosts: [.hosts.L[] | .S], memory: .memory.N, cpu: .cpu.N, constraint: .constraint.S, image_private: .image_private.BOOL | tostring} | tostring | @sh')
eval "SERVICE_ARRAY=(${PARSED})"
for I in "${SERVICE_ARRAY[@]}"; do
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
    SERVICE_HOSTS="$(echo "$I" | jq -r '.hosts[]')"
    SERVICE_ENV="$(echo "$I" | jq -r '.env[]')"
    SERVICE_LOG_DRIVER="$(echo "$I" | jq -r '.log_driver')"
    SERVICE_LOG_OPT="$(echo "$I" | jq -r '.log_opt[]')"
    SERVICE_HEALTH_CMD="$(echo "$I" | jq -r '.health_cmd')"
    SERVICE_SECRETS="$(echo "$I" | jq -r '.secrets[]')"
    SERVICE_CLABELS="$(echo "$I" | jq -r '.clabels[]')"
    PUBLISH=""
    REGISTRY_AUTH=""
    RESERVE_MEMORY=""
    RESERVE_CPU=""
    CONSTRAINT=""
    NETWORKS=""
    MOUNTS=""
    ADDHOSTS=""
    PASS_ENV=""
    LOG_DRIVER=""
    LOG_OPT=""
    HEALTH_CMD=""
    HEALTH_CMD_CMD="-d"
    SECRETS=""
    CONTAINER_LABELS=""

    if [[ "${SERVICE_LOG_DRIVER}" != "none" ]]; then
      LOG_DRIVER="--log-driver ${SERVICE_LOG_DRIVER}"
    fi

    for C in `echo ${SERVICE_CLABELS}`;
    do
      CONTAINER_LABELS="--container-label $C ${CONTAINER_LABELS}"
    done

    for L in `echo ${SERVICE_LOG_OPT}`;
    do
      LOG_OPT="--log-opt $L ${LOG_OPT}"
    done

    for M in `echo ${SERVICE_MOUNTS}`;
    do
      MOUNTS="--mount $M ${MOUNTS}"
    done

    for P in `echo ${SERVICE_PORTS}`;
    do
      PUBLISH="--publish $P ${PUBLISH}"
    done

    for E in `echo ${SERVICE_ENV}`;
    do
      PASS_ENV="--env $E ${PASS_ENV}"
    done

    for H in `echo ${SERVICE_HOSTS}`;
    do
      ADDHOSTS="--host $H ${ADDHOSTS}"
    done

    for N in `echo ${SERVICE_NETWORKS}`;
    do
      NETWORKS="--network $N ${NETWORKS}"
    done

    for S in `echo ${SERVICE_SECRETS}`;
    do
      SECRETS="--secret $S ${SECRETS}"
    done

    if [[ "${SERVICE_HEALTH_CMD}" != "none" ]]; then
      HEALTH_CMD="--health-cmd"
      HEALTH_CMD_CMD="${SERVICE_HEALTH_CMD}"
    fi

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
    docker service create --name "${SERVICE_NAME}" --replicas "${SERVICE_REPLICAS}" ${RESERVE_MEMORY} ${RESERVE_CPU} ${CONSTRAINT} --placement-pref 'spread=engine.labels.availability_zone' --mode "${SERVICE_MODE}" ${PASS_ENV} ${CONTAINER_LABELS} ${MOUNTS} ${HEALTH_CMD} "${HEALTH_CMD_CMD}" ${LOG_DRIVER} ${LOG_OPT} ${PUBLISH} ${NETWORKS} ${SECRETS} ${ADDHOSTS} ${REGISTRY_AUTH} ${SERVICE_IMAGE}
  else
    docker service scale "${SERVICE_NAME}=${SERVICE_REPLICAS}"
  fi
done

# TODO: docker service inspect NAME | jq -r '.[] | .Spec | {name: .Name, replicas: .Mode.Replicated.Replicas, mount: .sdf, mode: .Mode | keys[] | ascii_downcase, image: .TaskTemplate.ContainerSpec.Image | split("@")[0]}'
