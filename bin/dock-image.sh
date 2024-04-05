#! /usr/bin/env bash

if [[ -f python.sh ]]
then
  source python.sh
else
  if [[ -f docker.sh ]]
  then
    source docker.sh
  else
    echo >/dev/stderr "dock-image.sh: no python.sh or docker.sh file found"
    exit 1
  fi
fi

case $1 in
  "push")
    shift

    label=$1

    if [[ -z $label ]]
    then
      echo >/dev/stderr "dock-image.sh:  \"label\" not specified. exiting."
      exit 1
    fi

    docker image push $label
  ;;
  "pull")
    shift

    image=$1

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-image.sh: pull \"image\" not specified. exiting."
      exit 1
    fi

    docker pull "${DOCKER_USER}/${image}"
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
      echo >/dev/stderr "dock-image.sh: label (1) not specified. exiting."
      exit 1
    fi

    docker images --filter=label=${label}
  ;;
  "search")
    shift

    image=$1

    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-image.sh: search image (1) not specified. exiting."
      exit 1
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

    image=$1
    if [[ -z $image ]]
    then
      echo >/dev/stderr "dock-image.sh: delete image (1) not specified. exiting."
      exit 1
    fi

    docker rmi ${image}
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
  "inspect")
    shift

    image=$1

    if [[ -z $1 ]]
    then
      echo >/dev/null "no image specified. exiting."
      exit 1
    fi

    docker inspect ${image}
  ;;
  "export")
    shift

    if [[ -z $DOCKER_USER ]]
    then
      echo >/dev/null "dock-image.sh export - no user specified. exiting."
      exit 1
    fi

    name=$1

    if [[ -z $name ]]
    then
      echo >/dev/null "dock-image.sh export - no image specified. exiting."
      exit 1
    fi

    export_name=$(echo $name | tr -s ':' '_' | tr '-' '_')

    echo >/dev/stderr "dock-image.sh export ${DOCKER_USER}/${name} -> ${export_name}"
    docker save ${DOCKER_USER}/$name >${export_name}.tar

    if [[ $? -ne 0 ]]
    then
      echo /dev/stderr "dock-image.sh export encountered \"save\" error. cannot continue. exiting."
      rm ${export_name}.tar

      exit 1
    fi

    sha256sum ${export_name}.tar >${export_name}.tar.sha256
    xz -z ${export_name}.tar
  ;;
  *|"help")
cat <<HELP
dock-image.sh

pull       = pull IMAGE:VERSION
images     = show images
dangling   = show dangling images
prune      = prune dangling images
filter     = filter by EXPR
label      = list images with a matching label (1)
search     = search by MATCH (1) "official" as a second argument restricts to official images.
delete     = delete IMAGE (1)
nuke       = delete all images! will require confirmation
export     = export a image <image> to a xz compressed archive with a sha256 checksum
inspect    = inspect <image>
HELP
  ;;
esac
