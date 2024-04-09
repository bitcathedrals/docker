#! /usr/bin/env bash

DOCKER_PLATFORMS="linux/amd64,linux/arm64"

BUILDER="uber"

test -f python.sh && source python.sh

case $1 in
  "version")
    docker buildx version
  ;;
  "create")
    docker buildx create --name $BUILDER --platform=$DOCKER_PLATFORMS --use
  ;;
  "ls")
    docker buildx ls
  ;;
  "generate")
    shift
    source=$1

    if [[ -z $source ]]
    then
      echo >/dev/stderr "dock-build.sh: generate  - .org Dockerfile not given. exiting."
      exit 1
    fi

    org-compile.sh $source Dockerfile.python
  ;;
  "info")
    shift

    if [[ -n $DOCKER_USER ]]
    then
      user=$DOCKER_USER
    else
      user=$1
      shift
    fi

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock-build.sh: info - name argument not given. exiting."
      exit 1
    fi

    docker history "${DOCKER_USER}/$name"
  ;;
  "build")
    shift

    if [[ -n $DOCKER_USER ]]
    then
      user=$DOCKER_USER
    else
      user=$1
      shift
    fi

    if [[ -z $user ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - user argument not given. exiting."
      exit 1
    fi

    if [[ -n $BUILD_NAME ]]
    then
      name=$BUILD_NAME
    else
      name=$1
      shift
    fi

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - name argument not given. exiting."
      exit 1
    fi

    version=$1

    if [[ -z $version ]]
    then
      version=$DOCKER_VERSION
      shift
    fi

    if [[ -z $version ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - version argument not given. exiting."
      exit 1
    fi

    test -d docker && cd docker

    echo >/dev/stderr "dock-build.sh build - ($PWD) [$user/$name:$version] $DOCKER_PLATFORMS"

    echo >/dev/stderr "dock-build.sh build - ready?"

    read -p "Proceed? [y/n]: " proceed

    if [[ $proceed = "y" ]]
    then
      echo /dev/stderr ">>> proceeding with release start!"
    else
      echo /dev/stderr ">>> ABORT! exiting now!"
      exit 1
    fi

    if docker buildx build --builder=uber -t "$user/$name:$version" --platform="$DOCKER_PLATFORMS" --push .
    then
      echo /dev/stderr "dock-build.sh build - success!"
      echo "FROM $user/$name:$version" >Dockerfile.${name}-${version}
    else
      echo /dev/stderr "dock-build.sh build - failed!."
      exit 1
    fi
  ;;
  "help"|*)
cat <<HELP
version   = docker buildx version
create    = create a builder uber and set to "use"
ls        = list builders
generate  = generate Dockerfile.python from a .org docker template <org-file>
info      = show detailed information on <image>
build     =
HELP
  ;;
esac

exit 0
