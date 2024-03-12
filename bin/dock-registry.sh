#! /usr/bin/env bash

case $1 in
  "pull")
    shift

    image=$1

    version=$2

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-reg.sh: pull \"image\" not specified. exiting."
      exit 1.
    fi

    if [[ -z $version ]]
    then
      echo >/dev/stderr "dock-reg.sh: pull \"version\" not specified. exiting."
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
  "export")
    $0 images | grep -v REPOSITORY | tr -s ' ' | cut -d ' ' -f 1,2 | tr ' ' ':' | sed -e 's,^,dock-registry pull ,'
  ;;
  *|"help")
cat <<HELP

images     = ?FILTER show images with a optional regex pattern
pull       = IMAGE,VERSION pull IMAGE:VERSION
images     = show images
export     = export a list of commands to install a set of docker images
HELP
  ;;
esac
