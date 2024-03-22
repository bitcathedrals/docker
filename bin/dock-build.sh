#! /usr/bin/env bash

DOCKER_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

BUILDER="uber"

case $1 in
  "version")
    docker buildx version
  ;;
  "create")
    docker buildx create --name $BUILDER --platform=$DOCKER_PLATFORMS --use
  ;;
  "dockfile")
    shift

    source=$1

    if [[ -z $source ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - .org Dockerfile not given. exiting."
      exit 1
    fi

    org-compile.sh $source Dockerfile.python
  ;;
  "history")
    shift

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock-build.sh: history - name argument not given. exiting."
      exit 1
    fi

    docker history $name
  ;;
  "build")
    shift

    user=$1

    if [[ -z $user ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - user argument not given. exiting."
      exit 1
    fi

    shift

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - name argument not given. exiting."
      exit 1
    fi

    shift
    version=$1

    if [[ -z $version ]]
    then
      echo >/dev/stderr "dock-build.sh: dockfile - version argument not given. exiting."
      exit 1
    fi

    if docker buildx build --builder=uber -t "$user/$name:$version" --platform="$DOCKER_PLATFORMS" .
    then
      echo /dev/stderr "dock-build.sh build - success!"
      echo "FROM $user/$name:$version"
    else
      echo /dev/stderr "dock-build.sh build - failed!."
      exit 1
    fi
  ;;
  "help"|*)

  ;;
esac

exit 0
