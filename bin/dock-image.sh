#! /usr/bin/env bash


# https://www.howtogeek.com/devops/how-to-sign-your-docker-images-to-increase-trust/
# https://docs.docker.com/engine/security/trust/

if [[ -f python.sh ]]
then
  source python.sh
fi

if [[ -f docker.sh ]]
then
  source docker.sh
fi

export DOCKER_CONTENT_TRUST=1

function make_image_parameter {
  if [[ -n $DOCKER_IMAGE ]]
  then
    image=$DOCKER_IMAGE
    return
  fi

  image=$1

  if [[ -z $image ]]
  then
    echo >/dev/stderr "dock-image.sh: make_image_parameter \"image\" (1) not specified. exiting."
    exit 1
  fi

  echo "$image" | grep '/' -

  if [[ $? -ne 0 ]]
  then
    if [[ -n $DOCKER_USER ]]
    then
      image="${DOCKER_USER}/${image}"
    fi
  fi
}

case $1 in
  "push")
      shift

      make_image_parameter $@

      exec docker image push "$image"
      ;;
  "pull")
      shift

      make_image_parameter $@

      exec docker pull "${image}"
      ;;
  "images")
      shift

      filter=$1

      if [[ -n filter ]]
      then
          exec docker images | grep -E "$filter"
      else
          exec docker images
      fi
      ;;
  "dangling")
      exec docker images --filter dangling=true
      ;;
  "prune")
      exec docker image prune
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

      exec docker images --filter=label=${label}
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

      make_image_parameter $@

      exec docker rmi ${image}
  ;;
  "nuke")
      shift

      echo "NUKE! will delete all images!!"

      read -p "Proceed? [y/n]: " proceed

      if [[ $proceed = "y" ]]
      then
          echo ">>> proceeding with nuclear fire!"
          exec docker rmi $(docker images -q) -f
      else
          echo ">>> ABORT! exiting now!"
          exit 1
      fi
      ;;
  "inspect")
      shift

      make_image_parameter $@
      
      exec docker inspect ${image}
      ;;
  "export")
      shift

      make_image_parameter $@

      export_name=$(echo $image | tr -s ':' '_' | tr '-' '_')

      echo >/dev/stderr "dock-image.sh export ${image} -> ${export_name}"

      docker save "${image}" >${export_name}.tar

      if [[ $? -ne 0 ]]
      then
          echo /dev/stderr "dock-image.sh export encountered \"save\" error. cannot continue. exiting."
          rm ${export_name}.tar

          exit 1
      fi

      sha256sum ${export_name}.tar >${export_name}.tar.sha256
      xz -z ${export_name}.tar
      ;;
  "sign/generate")
      shift
      exec docker trust key generate codermattie
      ;;
  "sign/add")
    shift

    repository=$1
    shift

    exec docker trust signer add --key ~/.docker/trust/codermattie.pub codermattie codermattie/$repository
    ;;
  "sign/import")
      exec docker trust key load $1
      ;;
  "sign")
    shift

    repository=$1
    shift

    tag=$1
    shift

    exec docker trust sign ${DOCKER_USER}/${repository}:{tag}
    ;;
  "sign/check")
      shift
      exec docker trust signer add your-key-name registry.example.com/my-image
      ;;
  "cves")
      shift

      make_image_parameter $@

      exec docker-scout cves ${image} --exit-code --only-severity critical,high
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

sign/generate = generate a signature key pair
sign/add      = add repo keys
sign/import   = import a key
sign          = sign an image
HELP
  ;;
esac
