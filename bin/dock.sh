#! /usr/bin/env bash

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

function make_args {
  arguments=""

  if [[ -n $1 ]]
  then
    while [[ -n $1 ]]
    do
      case $1 in
        "arg/volume")
          shift

          host_path=$1
          if [[ -z $host_path ]]
          then
            echo >/dev/stderr "dock.sh: arg/volume - no arg given."
            exit 1
          fi

          if [[ ! -e $host_path ]]
          then
            echo >/dev/stderr "dock.sh: arg/volume - host path does not exist. exiting."
            exit 1
          fi

          shift
          container_path=$1

          arguments="${arguments} -v ${host_path}:${container_path}"
          shift
        ;;
        "arg/shell")
          arguments="${arguments} -i /bin/bash"
          shift
        ;;
        "arg/daemon")
          arguments="${arguments} -d"
          shift
        ;;
        "arg/restart")
          shift

          restart=""

          if [[ -z $1 ]]
          then
            echo >/dev/stderr "dock.sh: arg/daemon - no restart option specified. exiting."
            exit 1
          fi

          case $1 in
            "always")
              restart="always"
            ;;
            "unless")
              restart="unless-stopped"
             ;;
            "failed")
              restart="on-failure"
            ;;
            *)
              echo >/dev/stderr "dock.sh: arg/restart unknown option $1"
              exit 1
            ;;
          esac

          arguments="${arguments} --restart ${restart}"
          shift
        ;;
        "arg/port")
          shift

          arguments="${arguments} --publish $1"
          shift
        ;;

        "arg/name")
          shift

          arguments="${arguments} --name $1"
          shift
        ;;
        *)
          rest=$*
          return
        ;;
      esac
    done

    rest=$*
  fi

  rest=$*
}

function image_and_arguments {
  command=$1
  shift

  user=$DOCKER_USER
  if [[ -z $user ]]
  then
    echo >/dev/stderr "dock.sh: $command - \"user\" not specified. exiting."
    exit 1
  fi

  image=$DOCKER_IMAGE

  if [[ -z $image ]]
  then
    image="${BUILD_NAME}:${DOCKER_VERSION}"
  else
    image="${image}:${DOCKER_VERSION}"
  fi

  if [[ $command != 'purge' ]]
  then
     image="${user}/${image}"
  fi

  make_args $@
}

function name_and_arguments {
  command=$1
  shift

  name=$DOCKER_NAME

  if [[ -z $name ]]
  then
    name=$1
    shift
  fi

  if [[ -z $name ]]
  then
    echo >/dev/stderr "dock.sh: $command - name not specified. exiting."
    exit 1
  fi

  make_args $@
}

case $1 in
  "version")
    docker version
  ;;
  "login")
    docker login
  ;;
  "run")
    image_and_arguments $@

    eval "docker run $arguments ${image} $rest"
  ;;
  "pry")
    image_only $@
    docker run -it --entrypoint /bin/bash "${image}"
  ;;
  "start")
    name_and_arguments $@

    args=""
    
    if [[ $rest == "-i" ]]
    then
      args="-i -a"
    fi

    eval "docker start $arguments $args $name"
  ;;
  "attach")
    name_and_arguments $@
    eval "docker attach $arguments $name"
  ;;
  "exec")
    name_and_arguments $@
    eval "docker exec $arguments $name"
  ;;
  "running")
    docker ps
  ;;
  "all")
    docker ps -a
  ;;
  "stop")
    name_and_arguments $@
    eval "docker stop $arguments $name"
  ;;
  "delete")
    name_and_arguments $@
    eval "docker rm $arguments $name"
  ;;
  "purge")
    image_only $@

    for container in $(dock.sh all | grep ${image} | tr -s ' ' | cut -d ' ' -f 1)
    do
      echo "purging container: $container"
      dock.sh delete ${container}
    done
  ;;
  "cp-out")
    name_and_arguments $@

    source=`echo $arguments | cut -d ' ' -f 1`
    dest=`echo $arguments | cut -d ' ' -f 2`

    eval "docker cp \"$name:$source\" $dest"
  ;;
  *|"help")
    cat <<HELP
docker.sh
login         = login to docker account
version       = show docker version
run           = create & start container <NAME>
pry           = create & start container interactive with bash
attach        = attach to a running container <NAME> viewing/interacting with PID 1
exec          = exec a process inside the container <NAME> alongside PID 1
running       = show running containers only
all           = show running and stopped containers
stop          = stop a container by <NAME/ID>
delete        = delete a container by <NAME/ID>
purge         = delete all containers by <IMAGE>
cp            = copy a file out of the container <NAME> <container path> <destination>

arg/volume    = mount volume argument <HOST_PATH> <CONTAINER_PATH>
arg/daemon    = run detached in the background
arg/restart   = restart <always|unless|failed>
arg/shell     = invoke bash attached to terminal
arg/port      = map port:port
arg/name      = specify a name
HELP
  ;;
esac
