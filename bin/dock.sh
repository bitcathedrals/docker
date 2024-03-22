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

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock.sh: shell/version - either DOCKER_IMAGE or arg(1) not specified. exiting."
      exit 1
    fi

    if [[ -z $version ]]
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

    image=""

    if [[ -n $DOCKER_IMAGE ]]
    then
      image=$DOCKER_IMAGE
    else
      image=$1
      shift
    fi

    version=""

    if [[ -n $DOCKER_VERSION ]]
    then
      version=$DOCKER_VERSION
    else
      version=$1
      shift
    fi

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock.sh: run/version - either DOCKER_IMAGE or arg(1) not specified. exiting."
      exit 1
    fi

    if [[ -z $version ]]
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

    eval "docker run $name_cmd ${image}:${version} $restart $*"
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

    restart=""

    if [[ -n $1 ]]
    then
      case $1 in
        "restart")
          restart="--restart always"
        ;;
        "unless")
          restart="--restart unless-stopped"
        ;;
        "failure")
          restart="--restart on-failure"
        ;;
        *)
          echo >/dev/stderr "unknown option $1"
        ;;
      esac
    fi

    eval "docker run $name_cmd ${label} $restart $*"
  ;;
  "start")
    label=$1

    if [[ -z $label ]]
    then
      echo >/dev/stderr "dock.sh: start - label/id is missing. exiting."
      exit 1
    else
      shift
    fi

    eval "docker start $label $*"
  ;;
  "attach")
    shift

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: attach - name/id is missing. exiting."
    fi

    eval "docker exec -it $name bash $*"
  ;;
  "running")
   eval "docker ps $*"
  ;;
  "all")
    eval "docker ps -a $*"
  ;;
  "stop")
    shift

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: stop - name/id is missing. exiting."
      exit 1
    fi

    eval "docker stop $name $*"
  ;;
  "delete")
    shift

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: delete - name/id is missing. exiting."
      exit 1
    fi

    eval "docker rm $name $*"
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

    source_path=$1

    if [[ -z $source_path ]]
    then
      echo >/dev/stderr "dock.sh: cp - source path is missing. exiting."
      exit 1
    fi

    shift

    destination_path=$1

    if [[ -z $destination_path ]]
    then
      echo >/dev/stderr "dock.sh: cp - destination path is missing. using CWD - $PWD"
      destination_path=$PWD
    fi

    eval "docker cp "$label:$source_path" $destination_path $*"
  ;;
  "arg/volume")
    shift

    host_path=$1

    if [[ -z $host_path ]]
    then
      echo >/dev/stderr "dock.sh: arg/volume - no arg given."
      exit 1
    fi

    if [[ -e $host_path ]]
    then
      echo >/dev/stderr "dock.sh: arg/volume - host path is missing. exiting."
      exit 1
    fi

    shift

    container_path=$2

    echo "-v ${host_path}:${container_path}"
  ;;
  "arg/daemon")
    echo "-d"
  ;;
  "arg/restart")
    shift

    restart=""

    if [[ -z $1 ]]
    then
      echo >/dev/stderr "no restart option specified. exiting."
      exit 1
    fi

    case $1 in
      "restart")
        echo "--restart always"
      ;;
      "unless")
        echo "--restart unless-stopped"
      ;;
      "failure")
        echo "--restart on-failure"
      ;;
      *)
        echo >/dev/stderr "unknown option $1"
        exit 1
      ;;
    esac
  ;;
  "arg/name")
    name=""

    if [[ -z $1 ]]
    then
      echo >/dev/stderr "dock.sh: no name given. exiting."
      exit 1
    fi

    echo "--name $1"
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

arg/volume    = mount volume argument HOST_PATH (1) CONTAINER_PATH (2)
arg/daemon    = run detached in the background
arg/restart   = restart option always|unless-stopped|restart-on-failure
arg/name      = <name>
HELP
  ;;
esac
