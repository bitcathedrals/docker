#! /usr/bin/env bash

test -f docker.sh && source docker.sh

case $1 in
  "version")
    docker version
  ;;
  "login")
    docker login
  ;;
  "shell/version")
    shift

    if [[ -n $DOCKER_IMAGE ]]
    then
      image=$DOCKER_IMAGE
    else
      image=$1
      shift
    fi

    if [[ -n $DOCKER_VERSION ]]
    then
      version=$DOCKER_VERSION
    else
      version=$1
      shift
    fi

    if [[ -n $image ]]
    then
      echo >/dev/stderr "dock.sh: shell/version - either DOCKER_IMAGE or arg(1) not specified. exiting."
      exit 1
    fi

    if [[ -n $version ]]
    then
      echo >/dev/stderr "dock.sh: shell/version - either DOCKER_VERSION or arg(2|1 if DOCKER_IMAGE) not specified. exiting."
      exit 1
    fi

    name_cmd=""

    if [[ -n $1 ]]
    then
      name_cmd="--name $1"
      echo >/dev/stderr "dock.sh: shell/version - using name ${1}."
      shift
    fi

    eval "docker run -it $name_cmd ${image}:${version} $*"
  ;;
  "shell/name")
    shift

    label=$1

    if [[ -n $label ]]
    then
      echo >/dev/stderr "dock.sh: shell/name - name is missing. exiting."
      exit 1
    fi

    shift

    name_cmd=""

    if [[ -n $1 ]]
    then
      name_cmd="--name $1"
      echo >/dev/stderr "dock.sh: shell/version - using name ${1}."
      shift
    fi

    eval "docker run $name_cmd -it ${name} $*"
  ;;
  "run/version")
    shift

    if [[ -n $DOCKER_IMAGE ]]
    then
      image=$DOCKER_IMAGE
    else
      image=$1
      shift
    fi

    if [[ -n $DOCKER_VERSION ]]
    then
      version=$DOCKER_VERSION
    else
      version=$1
      shift
    fi

    if [[ -n $image ]]
    then
      echo >/dev/stderr "dock.sh: run/version - either DOCKER_IMAGE or arg(1) not specified. exiting."
      exit 1
    fi

    if [[ -n $version ]]
    then
      echo >/dev/stderr "dock.sh: run/version - either DOCKER_VERSION or arg(2|1 if DOCKER_IMAGE) not specified. exiting."
      exit 1
    fi

    name_cmd=""

    if [[ -n $1 ]]
    then
      name_cmd="--name $1"
      echo >/dev/stderr "dock.sh: shell/version - using name ${1}."
      shift
    fi

    eval "docker run $name_cmd ${image}:${version} $*"
  ;;
  "run/name")
    shift

    label=$1

    if [[ -n $label ]]
    then
      echo >/dev/stderr "dock.sh: run/name - label is missing. exiting."
      exit 1
    fi

    shift

    name_cmd=""

    if [[ -n $1 ]]
    then
      name_cmd="--name $1"
      echo >/dev/stderr "dock.sh: run/name - with name ${1}."
      shift
    fi

    eval "docker run $name_cmd ${label} $*"
  ;;
  "attach")
    shift

    name=$1

    if [[ -n $name ]]
    then
      echo >/dev/stderr "dock.sh: attach - name/id is missing. exiting."
    fi

    docker exec -it $name bash
  ;;
  "running")
   docker ps
  ;;
  "all")
    docker ps -a
  ;;
  "stop")
    shift

    name=$1

    if [[ -n $name ]]
    then
      echo >/dev/stderr "dock.sh: stop - name/id is missing. exiting."
      exit 1
    fi

    docker stop $name
  ;;
  "delete")
    shift

    name=$1

    if [[ -n $name ]]
    then
      echo >/dev/stderr "dock.sh: delete - name/id is missing. exiting."
      exit 1
    fi

    docker rm $name
  ;;
  "cp")
    shift

    label=$1

    if [[ -z $label ]]
    then
      echo >/dev/stderr "dock.sh: cp - label is missing. exiting."
      exit 1
    fi

    shift

    source_path = $1

    if [[ -z $source_path ]]
    then
      echo >/dev/stderr "dock.sh: cp - source path is missing. exiting."
      exit 1
    fi

    shift

    destination_path = $1

    if [[ -z $destination_path ]]
    then
      echo >/dev/stderr "dock.sh: cp - destination path is missing. using CWD - $PWD"
      destination_path=$PWD
    fi

    docker cp "$label:$source_path" $destination_path
  ;;
  "build")
    shift

    docker build $@
  ;;
  *|"help")
    cat <<HELP
docker.sh
login         = login to docker account
version       = show docker version
shell/version = open a shell in a container (DOCKER_IMAGE/(1),DOCKER_VERSION/(2)
shell/name    = open a shell in a container with LABEL (1)
run/version   = launch a container (DOCKER_IMAGE/(1),DOCKER_VERSION/(2)
run/name      = launch a container  with LABEL (1)
attach        = attach to a running container with LABEL/ID (1)
running       = show running containers only
all           = show running and stopped containers
stop          = stop a container by LABEL/ID (1)
delete        = delete a container by LABEL/ID (1)
cp            = copy a file out of the container LABEL/ID (1) container path (2) destination (3) default = "."
HELP
  ;;
esac
