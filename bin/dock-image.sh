#! /usr/bin/env bash


# https://www.howtogeek.com/devops/how-to-sign-your-docker-images-to-increase-trust/
# https://docs.docker.com/engine/security/trust/

test -f python.sh && source python.sh
test -f docker.sh && source docker.sh

export DOCKER_CONTENT_TRUST=1

dry='false'

function check_for_dry {
  if [[ $1 == "-dry" ]]
  then
    dry='true'
    return 0
  fi

  return 1
}

function make_image_parameter {
    check_for_dry $@ && shift

    if echo "$1" | grep -E '^/' -
    then
        image=$(echo $1 | sed -e 's,^/,,')
        return
    fi

    if [[ -n $DOCKER_IMAGE ]]
    then
        image=$DOCKER_IMAGE
    else
        if [[ -n ${BUILD_NAME} ]]
        then
            image=${BUILD_NAME}
        else
            image=$1
            shift

            if [[ -z $image ]]
            then
                echo >/dev/stderr "dock-image.sh: $command error! no DOCKER_IMAGE, BUILD_NAME, or image argument specified. exiting."
                exit 1
            fi
        fi
    fi

    user=$DOCKER_USER

    if [[ -n $user ]]
    then
        image="${user}/${image}"
        return
    fi

    user=$1

    if [[ -z $user ]]
    then
        echo >/dev/stderr "dock-image.sh: make_image_parameter \"user\" not specified. exiting."
        exit 1
    fi

    image="${user}/${image}"
}

case $1 in
  "push")
      shift
      make_image_parameter $@

      if [[ $dry == 'true' ]]
      then
          echo "docker image push \"$image\""
          exit 0
      fi

      exec docker image push "$image"

      ;;
  "pull")
      shift
      make_image_parameter $@

      if [[ $dry == 'true' ]]
      then
          echo "docker pull \"${image}\""
          exit 0
      fi

      exec docker pull "${image}"
      ;;
  "images")
      shift
      check_for_dry $@ && shift

      filter=$1

      if [[ -n filter ]]
      then
          if [[ $dry == 'true' ]]
          then
              echo "docker images | grep -E \"${filter}\""
              exit 0
          fi

          exec docker images | grep -E "$filter"
      else
          if [[ $dry == 'true' ]]
          then
              echo "docker images"
              exit 0
          fi

          exec docker images
      fi
      ;;
  "dangling")
      shift

      check_for_dry $@ && shift
      
      if [[ $dry == 'true' ]]
      then
          echo "docker images --filter dangling=true"
          exit 0
      fi

      exec docker images --filter dangling=true
      ;;
  "prune")
      shift
      check_for_dry $@ && shift
      
      if [[ $dry == 'true' ]]
      then
          echo "docker image prune"
          exit 0
      fi

      exec docker image prune
      ;;
  "filter")
      shift
      check_for_dry $@ && shift
      
      if [[ $dry == 'true' ]]
      then
          echo "docker images --filter=reference=\"$*\""
          exit 0
      fi

      eval "docker images --filter=reference=\"$*\""
      ;;
  "label")
      shift
      check_for_dry $@ && shift

      label=$1
      shift

      if [[ -z $label ]]
      then
          echo >/dev/stderr "dock-image.sh: label (1) not specified. exiting."
          exit 1
      fi

      if [[ $dry == 'true' ]]
      then
          echo "exec docker images --filter=label=${label}"
          exit 0
      fi

      exec docker images --filter=label=${label}
      ;;
  "search")
      shift
      check_for_dry $@ && shift

      if [[ $1 == "-official" ]]
      then
          official="--filter \"is-official=true\""
          shift
      else
          official=""
      fi

      query=$1
      shift

      if [[ -z $query ]]
      then
          echo >/dev/stderr "dock-image.sh: search (query) not specified. exiting."
          exit 1
      fi

      if [[ $dry == 'true' ]]
      then
          echo "docker search \"$query\" $official $* | tr -s ' ' | sort -k 1"
          exit 0
      fi

      eval "docker search \"$query\" $official $* | tr -s ' ' | sort -k 1"
  ;;
  "delete")
      shift
      make_image_parameter $@

      if [[ $dry == 'true' ]]
      then
          echo "docker rmi ${image}"
          exit 0
      fi

      exec docker rmi ${image}
  ;;
  "nuke")
      shift
      check_for_dry $@ && shift

      echo "NUKE! will delete all images!!"

      read -p "Proceed? [y/n]: " proceed

      if [[ $proceed = "y" ]]
      then
          if [[ $dry == 'true' ]]
          then
              echo "docker rmi $(docker images -q) -f"
              exit 0
          fi

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

      if [[ $dry == 'true' ]]
      then
          echo "docker inspect ${image}"
          exit 0
      fi

      exec docker inspect ${image}
      ;;
  "export")
      shift
      make_image_parameter $@

      export_name=$(echo $image | tr -s ':' '_' | tr '-' '_')

      echo >/dev/stderr "dock-image.sh export ${image} -> ${export_name}"

      if [[ $dry == 'true' ]]
      then
          echo "docker save "${image}" >${export_name}.tar"
          echo "sha256sum ${export_name}.tar >${export_name}.tar.sha256"
          echo "xz -z ${export_name}.tar"

          exit 0
      fi

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
      check_for_dry $@ && shift
 
      who=$1
      shift

      if [[ -z $who ]]
      then
          echo >/dev/stderr "dock-image.sh: error! sign/generate requires a user (1) argument. exiting."
          exit 1
      fi

      if [[ $dry == 'true' ]]
      then
          echo "docker trust key generate $who"
          exit 0
      fi

      exec docker trust key generate $who
      ;;
  "sign/add")
    shift
    check_for_dry $@ && shift

    key=$1
    shift

    if [[ -z $key ]]
    then
        echo >/dev/stderr "dock-image.sh: error! sign/add requires a key name (1) argument. exiting."
        exit 1
    fi

    repository=$1
    shift

    if [[ -z $repository ]]
    then
        echo >/dev/stderr "dock-image.sh: error! sign/add requires a user/repository (2) argument. exiting."
        exit 1
    fi

    if [[ $dry == 'true' ]]
    then
        echo "docker trust signer add --key ~/.docker/trust/$key.pub $key $repository"
        exit 0
    fi

    exec docker trust signer add --key ~/.docker/trust/$key.pub $key $repository
    ;;
  "sign/import")
      exec docker trust key load $1
      ;;
  "sign")
    shift
    make_image_parameter $@
 
    exec docker trust sign ${image}
    ;;
  "sign/check")
      echo >/dev/stderr "dock-image.sh sign/check not completed. exiting."
      exit 1

      shift
      check_for_dry $@ && shift

      if [[ $dry == 'true' ]]
      then
          echo "docker trust signer add your-key-name registry.example.com/my-image"
          exit 0
      fi

      exec docker trust signer add your-key-name registry.example.com/my-image
      ;;
  "cves")
      shift
      make_image_parameter $@

      if [[ $dry == 'true' ]]
      then
          echo "docker-scout cves ${image} --exit-code --only-severity critical,high"
          exit 0
      fi

      exec docker-scout cves ${image} --exit-code --only-severity critical,high
      ;;
  *|"help")
cat <<HELP
dock-image.sh

[ARGS]
-dry  = first arg

[IMAGE]

IMAGE = '/image' [final] | DOCKER_IMAGE | BUILD_NAME | (ARG)
USER = DOCKER_USER | (ARG) = <USER>/<IMAGE>

push       = push [ARGS] [IMAGE]
pull       = pull [ARGS] [IMAGE]
images     = show images [ARGS]
dangling   = show dangling images [ARGS]
prune      = prune dangling images [ARGS]
filter     = filter by EXPR [ARGS]
label      = list images with a matching label [ARGS] (label)
search     = search by MATCH [ARGS] (-official? = official only) " as a second argument restricts to official images.
delete     = delete IMAGE [ARGS] [IMAGE]
nuke       = delete all images! [ARGS] - will require confirmation
inspect    = inspect image [ARGS] [IMAGE]
export     = export a image [ARGS] [IMAGE] to a xz compressed archive with a sha256 checksum

sign/generate = generate a signature key pair [ARGS] (USER)
sign/add      = add repo keys [ARGS] (KEY) (REPOSITORY)
sign/import   = import a key [ARGS] (KEY)
sign          = sign an image [ARGS] [IMAGE]

cves          = check for vulnerabilities in image [ARGS] [IMAGE]
HELP
  ;;
esac
