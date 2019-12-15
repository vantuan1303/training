#!/bin/bash

# default parameters
DRIVER="virtualbox"
MANAGERS=1
WORKERS=2
DISK_SIZE="5000"
MEMORY="1024"
DOCKER_VERSION="https://github.com/boot2docker/boot2docker/releases/download/v19.03.5/boot2docker.iso"
ADDITIONAL_PARAMS=

function usage {
  echo "Usage: bash $0	[OPTIONS]
  
  Create and init a swarm cluster.
Options:
  -d, --driver                                virtual machine provider or cloud provider (default virtualbox)
  -m, --manager                               number of managers to create (default 1)
  -w, --worker                                number of workers to create (default 2)
  -v, --version                               boot2docker github url (default version 1.13.0)
  -ds, --disksize                             hard disk size for docker-machine (default 20GB)
  -r, --memory                                memory ram size for docker-machine (default 2GB)"
  exit 1
}

# get parameters
while [ "$#" -gt 0 ]; do
  case "$1" in
    --driver|-d)
    DRIVER="$2"
    shift 2
    ;;
    --manager|-m)
    MANAGERS="$2"
    shift 2
    ;;
    --worker|-w)
    WORKERS="$2"
    shift 2
    ;;
    --version|-v)
    DOCKER_VERSION="$2"
    shift 2
    ;;
    --disksize|-ds)
    DISK_SIZE="$2"
    shift 2
    ;;
    --memory|-r)
    MEMORY="$2"
    shift 2
    ;;
    -h|--help)
    usage
    ;;
  esac
done

if [ "$DRIVER" == "virtualbox" ]; then
  echo "-> about to create a swarm with $MANAGERS manager(s) and $WORKERS WORKERS on $DRIVER machines"
  ADDITIONAL_PARAMS="--virtualbox-disk-size ${DISK_SIZE} --virtualbox-memory ${MEMORY} --virtualbox-boot2docker-url=${DOCKER_VERSION}"
fi

function getIP {
  echo $(docker-machine ip $1)
}

function get_worker_token {
  # gets swarm manager token for a worker node
  echo $(docker-machine ssh manager1 docker swarm join-token worker -q)
}

function createManagerNode {
  # create manager machines
  for i in $(seq 1 $MANAGERS);
  do
    echo "== Creating manager$i machine ...";
    docker-machine create -d $DRIVER $ADDITIONAL_PARAMS manager$i

  done
}

function createWorkerNode {
  # create worker machines
  for i in $(seq 1 $WORKERS);
  do
    echo "== Creating worker$i machine ...";
    docker-machine create -d $DRIVER $ADDITIONAL_PARAMS worker$i
  done
}

function initSwarmManager {
  # initialize swarm mode and create a manager
  echo '============================================'
  echo "======> Initializing first swarm manager ..."
  docker-machine ssh manager1 docker swarm init --advertise-addr $(getIP manager1):2377
}

function join_node_swarm {
  # WORKERS join swarm
  for node in $(seq 1 $WORKERS);
  do
    echo "======> worker$node joining swarm as worker ..."
    docker-machine ssh worker$node docker swarm join --token $(get_worker_token) $(getIP manager1):2377
  done
}

# Display status
function status {
  echo "-> list swarm nodes"
  docker-machine ssh manager1 docker node ls
  echo
  echo "-> list machines"
  docker-machine ls
}

function main () {
  createManagerNode
  createWorkerNode
  initSwarmManager
  join_node_swarm
  status
}

main