#! /usr/bin/env bash

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

dry_run='false'
compose='false'
all='false'

arguments=""
before=""
rest=""

function before_args {
  if [[ -n $DOCKER_COMPOSE ]]
  then
    compose='true'
    arguments="${arguments} -p $DOCKER_COMPOSE"
  fi
}

function make_args {
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

          before="${before} -u $1"
          shift
        ;;
        "arg/env")
          shift

          before="${before} -e \"$1\""
          shift
        ;;
        "arg/follow")
          shift

          before="${before} --follow"
        ;;
        "arg/all")
          shift

          all="true"
          before="${before} -a"
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
            echo >/dev/stderr "dock.sh: arg/container - container not given. exiting."
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

          before="${before} --group-add $1"
          shift
        ;;
        "arg/caps")
          shift

          caps=$1
          shift

          DROP_CAPS=`echo "$caps" | cut -d ':' -f 1`
          ADD_CAPS=`echo "$caps" | cut -d ':' -f 2`

          if [[ -n $DROP_CAPS ]]
          then
            before="${before} --cap-drop $DROP_CAPS"
          fi

          if [[ -n $ADD_CAPS ]]
          then
            before="${before} --cap-add $ADD_CAPS"
          fi
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

          before="${before} -v ${vol}:${mount}:rw"
        ;;
        "arg/mirror")
          shift

          vol=$1
          shift

          if [[ -z $vol ]]
          then
            echo >/dev/stderr "dock.sh: arg/mirror - volume name not given. exiting."
            exit 1
          fi

          mount=$1
          shift

          if [[ -z $mount ]]
          then
            echo >/dev/stderr "dock.sh: arg/mirror - mount point not given. exiting."
            exit 1
          fi

          before="${before} -v ${vol}:${mount}:ro"
        ;;
        "arg/terminal")
          before="${before} -it"
          shift
        ;;
        "arg/entry")
          shift

          entry=$1
          shift

          before="--entrypoint $entry"
          ;;
        "arg/only")
          before="${before} --no-deps"
          shift
        ;;
        "arg/shell")
          before="${before} -it"
          rest="${rest} /bin/bash"
          shift
        ;;
        "arg/detach")
          shift
          before="${before} -d"
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

          before="${before} --restart ${restart}"
          shift
        ;;
        "arg/port")
          shift
          before="${before} --publish-all"
        ;;
        "arg/oneshot")
          shift

          before="${before} --rm"
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
        "arg/prod")
          shift
          before="${before} --tmpfs --read-only"
        ;;
        "arg/cpus")
          shift

          before="${before} --cpus $1"
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

  before_args $@

  if [[ $compose == 'true' ]]
  then
    resource=$1
    shift

    if [[ -z $resource ]]
    then
      echo >/dev/stderr "dock.sh: $command [resource_and_arguments] - error! when DOCKER_COMPOSE is specified a service argument must be specified"
      exit 1
    fi

    make_args $@
    return
  fi

  if [[ -n $DOCKER_IMAGE ]]
  then
    resource=$DOCKER_IMAGE
  else
    if [[ -n ${BUILD_NAME} ]]
    then
      resource=${BUILD_NAME}
    else
      resource=$1
      shift

      if [[ -z $resource ]]
      then
        echo >/dev/stderr "dock.sh: $command [resource_and_arguments] - error! no DOCKER_COMPOSE, DOCKER_IMAGE, BUILD_NAME, or argument specified. exiting."
        exit 1
      fi
    fi
  fi

  if [[ -n ${DOCKER_VERSION} ]]
  then
    resource="${resource}:${DOCKER_VERSION}"
  else
    echo >/dev/stderr "dock.sh: $command [resource_and_arguments] - warning! no DOCKER_VERSION specified, using argument as version."

    version=$1
    shift

    resource="${resource}:${version}"
  fi

  user=$DOCKER_USER

  if [[ -n $user ]]
  then
    echo "$image" | grep '/' -

    if [[ $? -ne 0 ]]
    then
      resource="${user}/${resource}"
    fi
  fi

  if [[ $command == "run" ]]
  then
    name=$1
    shift

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: $command [resource_and_arguments] - error! no name specified. exiting."
      exit 1
    fi
  fi

  make_args $@
}

function name_and_arguments {
  command=$1
  shift

  before_args=$@

  if [[ $compose == 'true' ]]
  then
    name=$1
    shift

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: $command [name_and_arguments] - error! name not specified. exiting."
      exit 1
    fi

    make_args $@
    return
  fi

  name=$DOCKER_NAME

  if [[ -z $name ]]
  then
    name=$1
    shift

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock.sh: $command [name_and_arguments] - error! name not specified. exiting."
      exit 1
    fi
  fi

  make_args $@
}

function arguments_only {
  command=$1
  shift

  before_args $@

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
      if [[ $dry_run == 'true' ]]
      then
        echo "docker compose ${arguments} run ${before} ${resource} ${rest}"
        exit 0
      fi

      exec docker compose ${arguments} run ${before} ${resource} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container run ${arguments} ${before} ${resource} ${rest}"
      exit 0
    fi

    eval "docker container run ${arguments} ${before} ${resource} ${rest}"
    exit $?
  ;;
  "pry")
    resource_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container run -it --rm ${arguments} --entrypoint /bin/bash ${before} ${resource} ${rest}"
      exit 0
    fi

    eval "docker container run -it --rm ${arguments} --entrypoint /bin/bash ${before} ${resource} ${rest}"
    exit $?
  ;;
  "start")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} start ${before} ${name} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container start ${arguments} ${before} ${name}  ${rest}"
      exit 0
    fi

    eval "docker container start ${arguments} ${before} ${name} ${name} ${rest}"
    exit $?
  ;;
  "attach")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container attach ${arguments} ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker container attach ${arguments} ${before} ${name} ${rest}"
    exit $?
  ;;
  "exec")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      if [[ $dry_run == 'true' ]]
      then
        echo "docker compose ${arguments} exec -it ${before} ${name} ${rest}"
        exit 0
      fi

      exec docker compose ${arguments} exec -it ${before} ${name} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container ${arguments} exec -it ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker container ${arguments} exec -it ${before} ${name} ${rest}"
    exit $?
  ;;
  "debug")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} exec -it ${before} ${name} /bin/bash ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container ${arguments} exec -it ${before} ${name} /bin/bash ${rest}"
      exit 0
    fi

    eval "docker container ${arguments} exec -it ${before} ${name} /bin/bash ${rest}"
    exit $?
  ;;
  "logs")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} logs ${before} ${name} -f ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container logs ${arguments} ${before} ${name} -f ${rest}"
      exit 0
    fi

    eval "docker container logs ${arguments} ${before} ${name} -f ${rest}"
    exit $?
  ;;
  "diff")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container diff ${arguments} ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker container diff ${arguments} ${before} ${name} ${rest}"
    exit $?
  ;;
  "info")
    shift

    kind=$1
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
      echo "docker $kind inspect -f json ${arguments} ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker $kind inspect -f json ${arguments} ${before} ${name} ${rest}"
    exit $?
  ;;
  "port")
    shift
    arguments_only $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} port ${before} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container ${arguments} port ${before} ${rest}"
      exit 0
    fi

    eval "docker container ${arguments} port ${before} ${rest}"
    exit $?
  ;;
  "ps")
    arguments_only $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} ls ${before} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container ${arguments} ls ${before} ${rest}"
      exit 0
    fi

    eval "docker container ${arguments} ls ${before} ${rest}"
    exit $?
  ;;
  "top")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} top ${before} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker $op ${arguments} top ${before} ${rest}"
      exit 0
    fi

    eval "docker $op ${arguments} top ${before} ${rest}"
    exit $?
  ;;
  "stop")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} -p ${name} stop ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container stop ${arguments} ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker container stop ${arguments} ${before} ${name} ${rest}"
    exit $?
  ;;
  "delete")
    name_and_arguments $@

    if [[ $compose == 'true' ]]
    then
      exec docker compose ${arguments} stop ${before} ${name} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container rm ${arguments} ${before} ${name} ${rest}"
      exit 0
    fi

    eval "docker container rm ${arguments} ${before} ${name} ${rest}"
    exit $?
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
      exec docker compose ${arguments} kill ${before} ${name} ${rest}
    fi

    if [[ $dry_run == 'true' ]]
    then
      echo "docker container ${arguments} kill ${before} $name ${rest}"
      exit 0
    fi

    eval "docker container ${arguments} kill ${before} $name ${rest}"
    exit $?
  ;;
  "newvol")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume ${arguments} create ${before} $name ${rest}"
      exit 0
    fi

    eval "docker volume ${arguments} create ${before} $name ${rest}"
    exit $?
  ;;
  "rmvol")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume ${arguments} rm ${before} $name ${rest}"
      exit 0
    fi

    eval "docker volume ${argumetns} rm ${before} $name ${rest}"
    exit $?
  ;;
  "newnet")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} create ${before} $name ${rest}"
      exit 0
    fi

    eval "docker network ${arguments} create ${before} $name ${rest}"
    exit $?
  ;;
  "rmnet")
    name_and_arguments $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} rm ${before} $name ${rest}"
      exit 0
    fi

    eval "docker network ${arguments} rm ${before} $name ${rest}"
    exit $?
  ;;
  "prunenet")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} prune ${before} ${rest}"
      exit 0
    fi

    eval "docker network ${arguments} prune ${before} ${rest}"
    exit $?
  ;;
  "networks")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker network ${arguments} ls ${before} ${rest}"
      exit 0
    fi

    eval "docker network ${arguments} ls ${before} ${rest}"
    exit $?
  ;;
  "cp")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker cp ${arguments} ${before} ${rest}"
      exit 0
    fi

    eval "docker cp ${arguments} ${before} ${rest}"
    exit $?
  ;;
  "volumes")
    arguments_only $@

    if [[ $dry_run == 'true' ]]
    then
      echo "docker volume ${arguments} ${before} ls ${rest}"
      exit 0
    fi

    eval "docker volume ${arguments} ${before} ls ${rest}"
    exit $?
  ;;
  "create")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} create --pull missing --remove-orphans ${before} ${rest}
  ;;
  "destroy")
    compose='true'
    name_and_arguments $@

    exec docker compose ${arguments}  rm -s -v ${before} {rest}
  ;;
  "up")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} up ${before} ${rest}
  ;;
  "down")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} down --remove-orphans ${before} ${rest}
  ;;
  "restart")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} restart ${before} ${rest}
  ;;
  "list")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} ls ${before} ${rest}
  ;;
  "images")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} images ${before} ${rest}
  ;;
  "pull")
    compose='true'
    arguments_only $@

    exec docker compose ${arguments} pull ${before} ${rest}
  ;;
  *|"help")
    cat <<HELP
[engine]

login         = login to docker account
version       = show docker version

[environment]

variables can be specified as exports or variables, or in python.sh, or docker.sh

DOCKER_IMAGE   = <IMAGE NAME>|'service' - use as image name, or service means return arg(1) as service name
DOCKER_VERSION = <VERSION> - version of the docker image
DOCKER_USER    = docker registry user name

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
arg/mount     = mount volume <VOL> <MOUNT> as RW
arg/mirror    = mount volume <VOL> <MOUNT> as RO
arg/restart   = restart <always|unless|failed>
arg/port      = map <port:port>
arg/user      = run as <USER> or <USER>:GROUP
arg/groups    = extra groups <GROUP,...>
arg/attach    = attach stdin,stdout,stderr on container run commands
arg/cpus      = use <CPUS> number of cpus

[container and compose]

arg/detach    = run docker compose/container in the background
arg/signal    = pass <SIGNAL> to container or compose with "kill"
arg/name      = specify <name> for container|compose, for compose must follow arg/compose
arg/terminal  = attach command to terminal
arg/shell     = invoke bash and attach to terminal
arg/oneshot   = delete container/service after running
arg/caps      = <DROP>:<ADD> capabilities
arg/entry     = override entry-point in container with <COMMAND>

[compose]

create   = create the compose services and resources
destroy  = <NAME> destroy all the resources of a compose
up       = create services and resources and start all services
down     = stop the services removing all resources
restart  = restart all stopped and running services
list     = list containers for compose
images   = list images used by the compose
pull     = pull container images

arg/compose   = specify the compose <FILE> name, can be specified multiple times
arg/dir       = <DIR> to run compose in when specifying arg/compose
arg/recreate  = for "up" force resources to be recreated even if config/image not changed
arg/only      = don't start linked dependencies

[general args]

arg/dry       = dry run, echo the command instead of running it

arg/args      = copy next positional argument as \$arguments
arg/env       = specify <VAR=VALUE> as a environment variable

arg/follow    = follow log output
arg/all       = show all containers
arg/rmvol     = argument to compose down, delete volumes
arg/bridge    = bridge network create [SUBNET] [IP-RANGE]
arg/overlay   = overlay network create [SUBNET] [IP-RANGE]

[volumes]

volumes       = show volumes
newvol        = create new <VOLUME>
rmvol         = delete <VOLUME>

[NETWORK]

networks      = list the networks
newnet        = create new network <NAME>
rmnet         = delete <NAME>
prunenet      = prune unused networks

[TIPS]

* put compose for each service in the repository for that service, combine with multiple
  arg/compose options, and run in a arg/dir which is the running environment containing
  all the mounted config files.
HELP
  ;;
esac
