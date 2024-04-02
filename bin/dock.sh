#! /usr/bin/env bash

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

dry_run='false'

function make_args {
  arguments=""

  if [[ -n $1 ]]
  then
    while [[ -n $1 ]]
    do
      case $1 in
        "arg/dry")
          shift

          dry_run='true'
        ;;
        "arg/user")
          shift

          arguments="${arguments} -u $1"
          shift
        ;;
        "arg/env")
          shift

          arguments="${arguments} -e \"$1\""
          shift
        ;;
        "arg/container-path")
          shift

          container=$1
          shift

          if [[ -z $container ]]
          then
            echo >/dev/stderr "dock.sh: arg/container-path - container name not given. exiting."
            exit 1
          fi

          path=$1
          shift

          if [[ -z $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/container-path - path not given. exiting."
            exit 1
          fi

          arguments="${arguments} \"$container:$path\""
          shift
        ;;
        "arg/host-path")
          shift

          path=$1
          shift

          if [[ -z $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/host-path - path not given. exiting."
            exit 1
          fi

          if [[ ! -e $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/host-path - path does not exist. exiting."
            exit 1
          fi

          arguments="${arguments} \"$path\""
          shift
        ;;
        "arg/groups")
          shift

          arguments="${arguments} --group-add $1"
          shift
        ;;
        "arg/mount")
          shift

          vol=$1
          shift

          if [[ -z $vol ]]
          then
            echo >/dev/stderr "dock.sh: arg/mount - volume name not given. exiting."
            exit 1
          fi

          mount_dir=$1

          if [[ -z $mount_dir ]]
          then
            echo >/dev/stderr "dock.sh: arg/mount - mount point not given. exiting."
            exit 1
          fi

          arguments="${arguments} -v ${vol}:${mount_dir}"
          shift
        ;;
        "arg/shell")
          arguments="${arguments} -it"
          shift
        ;;
        "arg/daemon")
          arguments="${arguments} -d"
          shift
        ;;
        "arg/detach")
          arguments="${arguments} --detach"
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

          arguments="${arguments} -p $1"
          shift
        ;;

        "arg/name")
          shift

          arguments="${arguments} --name $1"
          shift
        ;;
        "arg/compose")
          shift

          arguments="${arguments} -f $1"
          shift
        ;;
        "arg/rmvol")
          shift

          arguments="${arguments} --volumes"
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

    if [[ $dry_run == 'true' ]]
    then
      echo "docker run $arguments ${image} ${rest}"
    else
      eval "docker run $arguments ${image} ${rest}"
    fi
  ;;
  "pry")
    image_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker run -it --entrypoint /bin/bash ${image}"
    else
      docker run -it --entrypoint /bin/bash ${image}
    fi
  ;;
  "start")
    name_and_arguments $@

    args=""

    if [[ $rest == "-i" ]]
    then
      args="-i -a"
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker start ${arguments} ${args} ${name}"
    else
      eval "docker start ${arguments} ${args} ${name}"
    fi
  ;;
  "attach")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker attach ${arguments} ${name} ${rest}"
    else
      eval "docker attach ${arguments} ${name} ${rest}"
    fi
  ;;
  "exec")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker exec ${arguments} ${name} ${rest}"
    else
      eval "docker exec ${arguments} ${name} ${rest}"
    fi
  ;;
  "running")
    docker ps
  ;;
  "all")
    docker ps -a
  ;;
  "stop")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker stop ${arguments} ${name} ${rest}"
    else
      eval "docker stop ${arguments} ${name} ${rest}"
    fi
  ;;
  "delete")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker rm ${arguments} ${name} ${rest}"
    else
      eval "docker rm ${arguments} ${name} ${rest}"
    fi
  ;;
  "purge")
    image_and_arguments $@

    for container in $(dock.sh all | grep ${image} | tr -s ' ' | cut -d ' ' -f 1)
    do
      echo "purging container: $container"

      if [[ $dry_run == 'true' ]]
      then
        echo "dock.sh delete ${container}"
      else
        dock.sh delete ${container}
      fi
    done
  ;;
  "new")
    shift

    name=$1
    shift

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume create $name"
    else
      docker volume create $name
    fi
  ;;
  "rmvol")
    shift

    name=$1
    shift

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume rm $name"
    else
      docker volume rm $name
    fi
  ;;
  "cp")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker cp ${arguments}"
    else
      eval "docker cp ${arguments}"
    fi
  ;;
  "volumes")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker volumes ls"
    else
      docker volumes ls
    fi
  ;;
  "up")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose up ${arguments}"
    else
      docker compose up ${arguments}
    fi
  ;;
  "down")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose down ${arguments}"
    else
      docker compose down ${arguments}
    fi
  ;;
  "ps")
    if [[ $dry_run == 'true' ]]
    then
      echo docker compose ps ${arguments}
    else
      docker compose ps ${arguments}
    fi
  ;;
  "top")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose top ${arguments}"
    else
      docker compose top ${arguments}
    fi
  ;;
  "halt")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose stop ${arguments}"
    else
      docker compose stop ${arguments}
    fi
  ;;
  "restart")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose restart ${arguments}"
    else
      docker compose restart ${arguments}
    fi
  ;;
  "list")
    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ls ${arguments}"
    else
      docker compose ls ${arguments}
    fi
  ;;
  *|"help")
    cat <<HELP
[containers]

docker.sh
login         = login to docker account
version       = show docker version
run           = create & start container <NAME>
pry           = create & start container from <IMAGE> interactive with bash
attach        = attach to a running container <NAME> viewing/interacting with PID 1
exec          = exec a process inside the container <NAME> alongside PID 1
running       = show running containers only
all           = show running and stopped containers
stop          = stop a container by <NAME/ID>
delete        = delete a container by <NAME/ID>
purge         = delete all containers by <IMAGE>
cp            = copy a file in/out use <arg/container-path> <arg/host-path> or reversed args
new           = create new <VOLUME>
volumes       = show volumes
rmvol         = delete <VOLUME>

[compose]

up       = bring up the services
down     = stop the services
ps       = show status of each service
top      = show processes inside the services
halt     = stop the compose containers
restart  = restart the compose containers
list     = list compose container sets

[args]

arg/container-path  = specify <CONTAINER> <PATH> as a in container path cp
arg/host-path       = specify <PATH> as a host path for cp

arg/env       = specify <VAR=VALUE> as a environment variable
arg/mount     = mount volume <VOL> <MOUNT>
arg/daemon    = run containers detached in the background
arg/detatch   = run docker compose in the background
arg/restart   = restart <always|unless|failed>
arg/shell     = invoke bash attached to terminal
arg/port      = map <port:port>
arg/name      = specify <name> for container
arg/dry       = dry run, echo the command instead of running it
arg/user      = run as <USER> or <USER>:GROUP
arg/groups    = extra groups <GROUP,...>
arg/compose   = specify the compose file name
arg/rmvol     = argument to compose down, delete volumes
HELP
  ;;
esac
