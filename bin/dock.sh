#! /usr/bin/env bash

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

dry_run='false'
compose='false'
all='false'
service=''

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
          all="true"
          rest="${rest} -a"
        ;;
        "arg/service")
          shift

          compose='true'

          service=$1
          shift
        ;;
        "arg/signal")
          shift

          signal=$1
          shift

          rest="${rest} --signal ${signal}"
        ;;
        "arg/container")
          shift

          container=$1
          shift

          if [[ -z $container ]]
          then
            echo >/dev/stderr "dock.sh: arg/container - container name not given. exiting."
            exit 1
          fi

          path=$1
          shift

          if [[ -z $path ]]
          then
            echo >/dev/stderr "dock.sh: arg/container - path not given. exiting."
            exit 1
          fi

          rest="${rest} \"$container:$path\""
        ;;
        "arg/host")
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

          rest="${rest} \"$path\""
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

          mount=$1
          shift

          if [[ -z $mount ]]
          then
            echo >/dev/stderr "dock.sh: arg/mount - mount point not given. exiting."
            exit 1
          fi

          arguments="${arguments} -v ${vol}:${mount}"
        ;;
        "arg/terminal")
          arguments="${arguments} -it"
          shift
        ;;
        "arg/shell")
          arguments="${arguments} -it"
          rest="${rest} /bin/bash"
          shift
        ;;
        "arg/detach")
          shift
          rest="${rest} -d"
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
        "arg/oneshot")
          shift

          arguments="${arguments} --rm"
          shift
        ;;
        "arg/name")
          shift

          if [[ $compose == 'true' ]]
          then
            arguments="${arguments} -p $1"
          else
            arguments="${arguments} --name $1"
          fi

          shift
        ;;
        "arg/compose")
          shift
          compose='true'

          if [[ -n $1 ]] && [[ -e $1 ]]
          then
            arguments="${arguments} -f $1"
            shift
          fi
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

resource=""
name=""

function resource_and_arguments {
  command=$1
  shift

  default=$DOCKER_IMAGE
  parameter=''

  if [[ -n $default ]]
  then
    image=$default
  else
    if [[ -n ${BUILD_NAME} ]]
    then
      if [[ $command == "purge" ]] && [[ $all == 'true' ]]
      then
        resource=${BUILD_NAME}
        return
      fi

      if [[ -n ${DOCKER_VERSION} ]]
      then
        image="${BUILD_NAME}:${DOCKER_VERSION}"
      else
        echo >/dev/stderr "dock.sh resource_and_arguments: no DOCKER_VERSION specified, using BUILD_NAME and argument (1) as version."
        image="${BUILD_NAME}:${image}"
      fi
    else
      echo >/dev/stderr "dock.sh resource_and_arguments: no BUILD_NAME specified, using argument."

      parameter=$1
      shift

      if [[ -z $parameter ]]
      then
        echo >/dev/stderr "dock.sh resource_and_arguments: no resource (1) specified. exiting."
        exit 1
      fi
    fi
  fi

  make_args $@

  if [[ $command == 'purge' ]]
  then
    resource=$image
    return
  fi

  case $command in
    "run")
      name=$1
      shift

      if [[ -z $name ]]
      then
        echo >/dev/stderr "dock.sh resource_and_arguments: no name (2) specified. exiting."
        exit 1
      fi
      ;;
    *)
      echo >/dev/stderr "dock.sh: resource_and_arguments - proceeding with resource only (1)."
      ;;
  esac

  user=$DOCKER_USER

  if [[ -z $user ]]
  then
    echo >/dev/stderr "dock.sh: resource_and_arguments - \"user\" not specified as DOCKER_USER. exiting."
    exit 1
  fi

  resource="${user}/${image}"
}

function name_and_arguments {
  command=$1
  shift

  name=$DOCKER_NAME

  if [[ -z $name ]]
  then
    name=$DOCKER_COMPOSE

    if [[ -z $name ]]
    then
      name=$1
      shift
    fi
  fi

  if [[ -z $name ]]
  then
    echo >/dev/stderr "dock.sh: $command - name not specified. exiting."
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
    resource_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      eval "docker compose ${arguments} up ${rest}"
      exit $?
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container run ${arguments} ${resource} --name ${name} ${rest}"
    else
      eval "docker container run ${arguments} ${resource} --name ${name} ${rest}"
    fi
  ;;
  "pry")
    resource_and_arguments $@

    docker inspect "pry" >/dev/null 2>&1

    if [[ $? -eq 0 ]]
    then
      echo >/dev/stderr "dock.sh pry [container] \"pry\" exists, launching debug into existing container"
      $0 start pry
      $0 debug pry
      return
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container run -it --name pry --rm ${arguments} --entrypoint /bin/bash ${resource} ${rest}"
    else
      eval "docker container run -it --name pry --rm ${arguments} --entrypoint /bin/bash ${resource} ${rest}"
    fi
  ;;
  "start")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      eval "docker compose ${arguments} -p ${name} start ${rest}"
      exit 0
    fi

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

    if [[ $compose == 'true' ]]
    then
      operation='compose'
    else
      operation='container'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $operation exec ${arguments} ${name} ${rest}"
    else
      eval "docker $operation exec ${arguments} ${name} ${rest}"
    fi
  ;;
  "debug")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      operation='compose'
    else
      operation='container'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $operation exec ${arguments} -it ${name} /bin/bash ${rest}"
    else
      eval "docker $operation exec ${arguments} -it ${name} /bin/bash ${rest}"
    fi
  ;;
  "logs")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      operation='compose'
    else
      operation='container'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $operation logs ${arguments} ${name} -f ${rest}"
    else
      eval "docker $operation logs ${arguments} ${name} -f ${rest}"
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
    arguments_only $@

    if [[ $compose == 'true' ]]
    then
      operation='compose'
    else
      operation='container'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $operation ${arguments} port ${rest}"
    else
      eval "docker $operation ${arguments} port ${rest}"
    fi
  ;;
  "ps")
    arguments_only $@

    op='container'

    if [[ $compose == 'true' ]]
    then
      op='compose'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $op ${arguments} ls ${rest}"
    else
      eval "docker $op ${arguments} ls ${rest}"
    fi
  ;;
  "top")
    name_and_arguments $@

    op='container'

    if [[ $compose == 'true' ]]
    then
      op='compose'
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $op ${arguments} top ${rest}"
    else
      eval "docker $op ${arguments} top ${rest}"
    fi
  ;;
  "stop")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      eval "docker compose ${arguments} -p ${name} stop ${rest}"
      return
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container stop ${arguments} ${name} ${rest}"
    else
      eval "docker container stop ${arguments} ${name} ${rest}"
    fi
  ;;
  "delete")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      eval "docker compose ${arguments} -p ${name} stop -s ${rest}"
      return
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container rm ${arguments} ${name} ${rest}"
    else
      eval "docker container rm ${arguments} ${name} ${rest}"
    fi
  ;;
  "purge")
    resource_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo >/dev/stderr "dock.sh purge: purging with resource $resource - dry/run"
    fi

    for container in $(dock.sh ps arg/all | grep ${resource} | tr -s ' ' | cut -d ' ' -f 1)
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
  "kill")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      eval "docker compose ${arguments} -p $name kill ${service} ${rest}"
    else
      if [[ $dry_run == 'true' ]]
      then
        echo "docker container ${arguments} kill $name ${rest}"
      else
        eval "docker container ${arguments} kill $name ${rest}"
      fi
    fi
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
  "networks")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} ls ${rest}"
    else
      eval "docker network ${arguments} ls ${rest}"
    fi
  ;;
  "cp")
    arguments_only $@

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

    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ${arguments} create --pull missing --remove-orphans ${rest}"
    else
      eval "docker compose ${arguments} create --pull missing --remove-orphans ${rest}"
    fi
  ;;
  "down")
    compose='true'
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ${arguments} down ${rest}"
    else
      eval "docker compose ${arguments} down ${rest}"
    fi
  ;;
  "restart")
    compose='true'
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ${arguments} restart ${rest}"
    else
      eval "docker compose ${arguments} restart ${rest}"
    fi
  ;;
  "list")
    compose='true'
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ${arguments} ls ${rest}"
    else
      eval "docker compose ${arguments} ls ${rest}"
    fi
  ;;
  "images")
    compose='true'
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker compose ${arguments} images"
    else
      eval "docker compose ${arguments} images"
    fi
  ;;
  *|"help")
    cat <<HELP
[engine]

login         = login to docker account
version       = show docker version

[containers & compose]

run           = create & start container/compose <RESOURCE> <NAME> resource=default|image|compose file , NAME=default|identifier to assign

exec          = exec a process inside the container/compose <NAME> [arg/service] alongside PID 1
debug         = exec a bash inside the container/service <NAME> alongside PID 1
ps            = show running containers or compose services, need arg/compose with arg/name after to show a compose
logs          = show logs in follow mode for container/compose
top           = show running processes
port          = show port mappings for container/compose
stop          = stop a container/compose by <NAME>
delete        = delete a container/compose by <NAME/ID>
kill          = <SIGNAL> send a signal to the container or compose, arg/service can be used.

[containers]

pry           = create & start container from <IMAGE> interactive with bash
attach        = attach to a running container <NAME> viewing/interacting with PID 1
diff          = show changes in a container from baseline image
purge         = delete all containers by <IMAGE>
cp            = copy a file in/out use <arg/container> <arg/host> or reversed args
info          = show detailed information about [container|volume|network] (1), name (2)
top           = show processes for container/compose

arg/container = specify <CONTAINER> <PATH> as a in container path cp
arg/host      = specify <PATH> as a host path for cp
arg/mount     = mount volume <VOL> <MOUNT>
arg/restart   = restart <always|unless|failed>
arg/port      = map <port:port>
arg/user      = run as <USER> or <USER>:GROUP
arg/groups    = extra groups <GROUP,...>

[volumes]

volumes       = show volumes
newvol        = create new <VOLUME>
rmvol         = delete <VOLUME>

[NETWORK]

networks      = list the networks
newnet        = create new network <NAME>
rmnet         = delete <NAME>
prunenet      = prune unused networks

[container and compose]

arg/detach    = run docker compose/container in the background
arg/signal    = pass <SIGNAL> to container or compose with "kill"
arg/name      = specify <name> for container|compose, for compose must follow arg/compose
arg/terminal  = attach command to terminal
arg/shell     = invoke bash attached to terminal
arg/oneshot   = delete container/service after running

[compose]

create   = create the compose services and resources
down     = stop the services removing all resources
restart  = restart all stopped and running services
list     = list containers for compose
images   = list images used by the compose

arg/compose   = specify the compose <FILE> name, can be specified multiple times
arg/attach    = attach to compose
arg/dir       = <DIR> to run compose in when specifying arg/compose
arg/recreate  = for "create" force containers to be recreated even if config/image not changed


[general args]

arg/dry       = dry run, echo the command instead of running it

arg/service   = specify a service for compose commands
arg/args      = copy next positional argument as \$arguments
arg/env       = specify <VAR=VALUE> as a environment variable

arg/follow    = follow log output
arg/all       = show all containers
arg/rmvol     = argument to compose down, delete volumes
arg/bridge    = bridge network create [SUBNET] [IP-RANGE]
arg/overlay   = overlay network create [SUBNET] [IP-RANGE]

[TIPS]

* put compose for each service in the repository for that service, combine with multiple
  arg/compose options, and run in a arg/dir which is the running environment containing
  all the mounted config files.
HELP
  ;;
esac
