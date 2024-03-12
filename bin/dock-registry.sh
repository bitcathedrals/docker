#! /usr/bin/env bash

case $1 in
  "pull")
    shift

    image=$1

    version=$2

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-registry.sh: pull \"image\" not specified. exiting."
      exit 1.
    fi

    if [[ -z $version ]]
    then
      echo >/dev/stderr "dock-registry.sh: pull \"version\" not specified. exiting."
      exit 1.
    fi

    docker pull "${image}:${version}"
  ;;
  "images")
    shift

    filter=$1

    if [[ -n filter ]]
    then
      docker images | grep -E "$filter"
    else
      docker images
    fi
  ;;
  "dangling")
    docker images --filter dangling=true
  ;;
  "prune")
    docker image prune
  ;;
  "filter")
    shift
    eval "docker images --filter=reference=\"$*\""
  ;;
  "label")
    shift

    label=$1

    if [[ -z $label ]]
    then
      echo >/dev/stderr "dock-registry.sh: label (1) not specified. exiting."
      exit 1.
    fi

    docker images --filter=label=${label}
  ;;
  "search")
    shift

    image=$1

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-registry.sh: search image (1) not specified. exiting."
      exit 1.
    fi

    shift

    if [[ $1 == "official" ]]
    then
      official="--filter \"is-official=true\""
    else
      official=""
    fi

    shift

    eval "docker search \"$image\" $official $* | tr -s ' ' | sort -k 1"
  ;;
  "delete")
    shift

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-registry.sh: delete image (1) not specified. exiting."
      exit 1.
    fi

    docker rmi $image
  ;;
  "nuke")
    shift

    echo "NUKE! will delete all images!!"

    read -p "Proceed? [y/n]: " proceed

    if [[ $proceed = "y" ]]
    then
      echo ">>> proceeding with nuclear fire!"
      docker rmi $(docker images -q) -f
    else
      echo ">>> ABORT! exiting now!"
      exit 1
    fi
  ;;
  "export")
    $0 images | grep -v REPOSITORY | tr -s ' ' | cut -d ' ' -f 1,2 | tr ' ' ':' | sed -e 's,^,dock-registry pull ,'
  ;;
  *|"help")
cat <<HELP

images     = ?FILTER show images with a optional regex pattern
pull       = IMAGE,VERSION pull IMAGE:VERSION
images     = show images
dangling   = show dangling images
prune      = prune dangling images
filter     = filter by EXPR
label      = list images with a matching label (1)
export     = export a list of commands to install a set of docker images
HELP
  ;;
esac
