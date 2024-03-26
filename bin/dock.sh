#! /usr/bin/env bash

test -f docker.sh && source docker.sh

case $1 in
  "version")
    docker version
  ;;
  "login")
    docker login
  ;;
  "run")
    shift
    image=""

    if [[ -n $DOCKER_IMAGE ]]
    then
      image=$DOCKER_IMAGE
    else
      image=$1
      shift
    fi

    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock.sh: run - either DOCKER_IMAGE or arg(1) not specified. exiting."
      exit 1
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: run - either DOCKER_NAME or arg(2|1 if DOCKER_NAME) not specified. exiting."
      exit 1
    fi

    eval "docker run --name $name ${image} $*"
  ;;
  "start")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: start - name/id is missing. exiting."
      exit 1
    fi

    eval "docker start $name $*"
  ;;
  "attach")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: attach - name/id is missing. exiting."
      exit
    fi

    eval "docker attach $name $*"
  ;;
  "exec")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: exec - name/id is missing. exiting."
      exit
    fi

    eval "docker exec $name $*"
  ;;
  "running")
   eval "docker ps $*"
  ;;
  "all")
    shift
    eval "docker ps -a $*"
  ;;
  "stop")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: exec - name/id is missing. exiting."
      exit 1
    fi

    eval "docker stop $name $*"
  ;;
  "delete")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: rm - name/id is missing. exiting."
      exit 1
    fi

    eval "docker rm $name $*"
  ;;
  "cp")
    shift
    name=""

    if [[ -n $DOCKER_NAME ]]
    then
      name=$DOCKER_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: cp - name/id is missing. exiting."
      exit 1
    fi

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

    eval "docker cp "$name:$source_path" $destination_path $*"
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
  "arg/shell")
    echo "-it /bin/bash"
  ;;
  *|"help")
    cat <<HELP
docker.sh
login         = login to docker account
version       = show docker version
run           = create & start container (DOCKER_IMAGE/(1),DOCKER_VERSION/(2)
attach        = attach to a running container NAME viewing/interacting with PID 1
exec          = exec a process inside the container NAME alongside PID 1
running       = show running containers only
all           = show running and stopped containers
stop          = stop a container by NAME/ID (1)
delete        = delete a container by NAME/ID (1)
cp            = copy a file out of the container NAME/ID (1) container path (2) destination (3) default = "."

arg/volume    = mount volume argument HOST_PATH (1) CONTAINER_PATH (2)
arg/daemon    = run detached in the background
arg/restart   = restart option always|unless-stopped|restart-on-failure
arg/name      = <name>
arg/shell     = "invoke bash attached to terminal
HELP
  ;;
esac
