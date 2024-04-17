#! /usr/bin/env bash

command=$1
shift

case $command in
  "remove")
    doas apt remove docker.io docker-compose docker-compose-v2 docker-doc podman-docker runc docker-buildx
    ;;
  "repository")
    doas apt install ca-certificates curl
    doas install -m 0755 /etc/apt/keyrings

    doas curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    doas chmod a+r /etc/apt/keyrings/docker.asc

    arch=$(dpkg --print-architecture)

    source /etc/os-release

    if [[ -n $UBUNTU_CODENAME ]]
    then
      release=$UBUNTU_CODENAME
    else
      if [[ -n $VERSION_CODENAME ]]
      then
        release=$VERSION_CODENAME
      else
        echo >/dev/stderr "dock-ubuntu.sh: error! cant find VERSION_CODENAME|UBUNTU_CODENAME in /etc/os-release"
        exit 1
      fi
    fi

    repo="deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $release stable"

    doas bash -c "echo \"$repo\" >/etc/apt/sources.list.d/docker.list"

    echo >/dev/stderr "dock-ubuntu.sh: updating packages."
    doas apt update
    ;;
  "install")
    doas apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ;;
  "enable")
    doas systemctl start docker && doas systemctl enable docker
    ;;
  "test")
    docker run hello-world
    ;;
  *|"help")
    echo <<HELP
dock-ubuntu.sh
remove     = remove existing ubuntu packages
repository = set up the official repository
install    = install the official packages
enable     = start and enable the new docker install
test       = test the new docker install
HELP
    ;;
esac
