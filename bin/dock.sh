#! /usr/bin/env bash

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

dry_run='false'
compose='false'

function make_args {
  arguments=""
  rest=""

  if [[ -n $1 ]]
  then
    while [[ -n $1 ]]
    do
      case $1 in
        "arg/args")
          shift

          arguments="${arguments} -u $1"
          shift
        ;;
        "arg/dry")
          shift

          dry_run='true'

          if [[ $compose == 'true' ]]
          then
            arguments="${arguments} --dry-run"
          fi
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
        "arg/follow")
          shift

          rest="${rest} --follow"
        ;;
        "arg/all")
          shift

          rest="${rest} -a"
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
            echo >/dev/stderr "dock.sh: arg/host-path - path: $path does not exist. exiting."
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
        "arg/bridge")
          shift

          arguments="${arguments} -d bridge"

          subnet=$1

          if [[ -z $subnet ]]
          then
            continue
          else
            shift
          fi

          arguments="${arguments} --subnet $subnet"

          ip_range=$1

          if [[ -z $ip_range ]]
          then
            continue
          else
            shift
          fi

          arguments="${arguments} --ip-range $ip_range"
        ;;
        "arg/overlay")
          shift

          arguments="${arguments} -d overlay"

          subnet=$1

          if [[ -z $subnet ]]
          then
            continue
          else
            shift
          fi

          arguments="${arguments} --subnet $subnet"

          ip_range=$1

          if [[ -z $ip_range ]]
          then
            continue
          else
            shift
          fi

          arguments="${arguments} --ip-range $ip_range"
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
          rest="${rest} --detach"
          shift
        ;;
        "arg/dir")
          shift

          path=$1
          shift

          if [[ -z $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/dir - path not given. exiting."
            exit 1
          fi

          if [[ ! -d $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/dir - directory: $path does not exist. exiting."
            exit 1
          fi

          arguments="${arguments} --project-directory \"$path\""
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
        "arg/attach")
          shift

          arguments="${arguments} --attach"
          shift
        ;;
        "arg/rmvol")
          shift

          arguments="${arguments} --volumes"
          shift
        ;;
        "arg/recreate")
          shift

          arguments="${rest} --force-recreate"
          shift
        ;;
        "arg/tail")
          shift

          count=$1
          shift

          rest="${rest} --tail ${count}"
        ;;
        *)
          rest=$*
          return
        ;;
      esac
    done

    rest="${rest} $*"
  fi

  rest="${rest} $*"
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

service_operation=""
service_name=""

function service_arguments {
  command=$1
  shift

  compose='true'

  operation=$1
  shift

  if [[ -z $operation ]]
  then
    echo >/dev/stderr "dock.sh: service operation not specified. exiting."
    exit 1
  fi

  case $operation in
    "exec"|"logs"|"kill")
      echo >/dev/stderr "dock.sh: configuring for service $operation."
      service_operation=$operation
    ;;
    *)
      echo >/dev/stderr "dock.sh: service operation not up|exec|logs. exiting."
      exit 1
    ;;
  esac

  service_name=$1
  shift

  if [[ -z $service_name ]]
  then
    echo >/dev/stderr "dock.sh: service name not specified. exiting."
    exit 1
  fi

  make_args $@
}

identifier=""
function identifier_and_arguments {
  command=$1
  shift

  identifier=$1
  shift

  make_args $@
}

function arguments_only {
  command=$1
  shift

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
      echo "docker container run ${arguments} ${image} ${rest}"
    else
      eval "docker container run ${arguments} ${image} ${rest}"
    fi
  ;;
  "pry")
    image_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container run -it --entrypoint /bin/bash ${image} ${rest}"
    else
      eval "docker container run -it --entrypoint /bin/bash ${image} ${rest}"
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
      echo "docker container start ${arguments} ${args} ${name}"
    else
      eval "docker container start ${arguments} ${args} ${name}"
    fi
  ;;
  "attach")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container attach ${arguments} ${name} ${rest}"
    else
      eval "docker container attach ${arguments} ${name} ${rest}"
    fi
  ;;
  "exec")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container exec ${arguments} ${name} ${rest}"
    else
      eval "docker container exec ${arguments} ${name} ${rest}"
    fi
  ;;
  "logs")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container logs ${arguments} ${name} ${rest}"
    else
      eval "docker container logs ${arguments} ${name} ${rest}"
    fi
  ;;
  "diff")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container diff ${arguments} ${name} ${rest}"
    else
      eval "docker container diff ${arguments} ${name} ${rest}"
    fi
  ;;
  "info")
    shift

    kind=$1
    shift

    case $kind in
      "container"|"volume"|"network")
      ;;
      *)
        echo /dev/stderr "dock.sh info: unrecognized type: $kind. exiting."
        exit 1
        ;;
    esac

    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $kind inspect -f json ${arguments} ${name} ${rest}"
    else
      eval "docker $kind inspect -f json ${arguments} ${name} ${rest}"
    fi
  ;;
  "port")
    shift

    kind=$1
    shift

    case $kind in
      "container"|"compose")
      ;;
      *)
        echo /dev/stderr "dock.sh port: unrecognized type: $1. exiting."
        exit 1
        ;;
    esac

    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $kind ${arguments} port ${name} ${rest}"
    else
      eval "docker $kind ${arguments} port ${name} ${rest}"
    fi
  ;;
  "running")
    arguments_only $@

    docker container ${arguments} ls ${rest}
  ;;
  "stop")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container stop ${arguments} ${name} ${rest}"
    else
      eval "docker container stop ${arguments} ${name} ${rest}"
    fi
  ;;
  "delete")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container rm ${arguments} ${name} ${rest}"
    else
      eval "docker container rm ${arguments} ${name} ${rest}"
    fi
  ;;
  "purge")
    image_and_arguments $@

    for container in $(dock.sh running arg/all | grep ${image} | tr -s ' ' | cut -d ' ' -f 1)
    do
      echo "purging container: $container"

      if [[ $dry_run == 'true' ]]
      then
        echo "$0 delete ${container}"
      else
        $0 delete ${container}
      fi
    done
  ;;
  "newvol")
    identifier_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume ${arguments} create $name ${rest}"
    else
      eval "docker volume ${arguments} create $name ${rest}"
    fi
  ;;
  "rmvol")
    identifier_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume ${arguments} rm $name ${rest}"
    else
      eval "docker volume ${argumetns} rm $name ${rest}"
    fi
  ;;
  "newnet")
    identifier_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} create $name ${rest}"
    else
      eval "docker network ${arguments} create $name ${rest}"
    fi
  ;;
  "rmnet")
    identifier_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} rm $name ${rest}"
    else
      eval "docker network ${arguments} rm $name ${rest}"
    fi
  ;;
  "prunenet")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} prune ${rest}"
    else
      eval "docker network ${arguments} prune ${rest}"
    fi
  ;;
  "lsnet")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} ls ${rest}"
    else
      eval "docker network ${arguments} ls ${rest}"
    fi
  ;;
  "cp")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker cp ${arguments} ${rest}"
    else
      eval "docker cp ${arguments} ${rest}"
    fi
  ;;
  "volumes")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volumes ${arguments} ls ${rest}"
    else
      eval "docker volumes ${arguments} ls ${rest}"
    fi
  ;;
  "create")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} create --pull missing --remove-orphans ${rest}"
  ;;
  "up")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} up ${rest}"
  ;;
  "down")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} down ${rest}"
  ;;
  "ps")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} ps ${rest}"
  ;;
  "top")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} top ${rest}"
  ;;
  "halt")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} stop ${rest}"
  ;;
  "restart")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} restart ${rest}"
  ;;
  "list")
    compose='true'
    arguments_only $@

    eval "docker compose ${arguments} ls ${rest}"
  ;;
  "do")
    compose='true'
    service_arguments $@

    eval "docker compose ${arguments} ${service_operation} ${service_name} ${rest}"
  ;;
  *|"help")
    cat <<HELP
[containers]

docker.sh
login         = login to docker account
version       = show docker version
run           = create & start container <NAME>
pry           = create & start container from <IMAGE> interactive with bash
diff          = show changes in a container from baseline image
info          = show detailed information about a container, will print in JSON
attach        = attach to a running container <NAME> viewing/interacting with PID 1
exec          = exec a process inside the container <NAME> alongside PID 1
running       = show running containers only
stop          = stop a container by <NAME/ID>
delete        = delete a container by <NAME/ID>
purge         = delete all containers by <IMAGE>
cp            = copy a file in/out use <arg/container-path> <arg/host-path> or reversed args

[volumes]

volumes       = show volumes
newvol        = create new <VOLUME>
rmvol         = delete <VOLUME>

[NETWORK]

newnet        = create new network <NAME>
rmnet         = delete <NAME>
prunenet      = prune unused networks
port          = <container|compose> <name> show port mappings

[compose]

up       = bring up the services
down     = stop the services
ps       = show status of each service
top      = show processes inside the services
halt     = stop the compose containers
restart  = restart the compose containers
list     = list containers for compose
do       = do <exec|logs|kill> <SERVICE>

[args]

arg/container-path  = specify <CONTAINER> <PATH> as a in container path cp
arg/host-path       = specify <PATH> as a host path for cp

arg/args      = copy next positional argument as \$arguments
arg/all       = show all containers
arg/env       = specify <VAR=VALUE> as a environment variable
arg/mount     = mount volume <VOL> <MOUNT>
arg/daemon    = run containers detached in the background
arg/detach    = run docker compose in the background
arg/restart   = restart <always|unless|failed>
arg/shell     = invoke bash attached to terminal
arg/port      = map <port:port>
arg/name      = specify <name> for container
arg/dry       = dry run, echo the command instead of running it
arg/user      = run as <USER> or <USER>:GROUP
arg/groups    = extra groups <GROUP,...>
arg/compose   = specify the compose <FILE> name, can be specified multiple times
arg/rmvol     = argument to compose down, delete volumes
arg/attach    = attach to compose
arg/dir       = <DIR> to run compose in when specifying arg/compose
arg/recreate  = for "create" force containers to be recreated even if config/image not changed
arg/tail      = tail <COUNT> last lines of logs
arg/follow    = follow log output
arg/bridge    = bridge network create [SUBNET] [IP-RANGE]
arg/overlay   = overlay network create [SUBNET] [IP-RANGE]

[TIPS]

* put compose for each service in the repository for that service, combine with multiple
  arg/compose options, and run in a arg/dir which is the running environment containing
  all the mounted config files.
HELP
  ;;
esac
