#!/bin/bash


echo "Activating feature clipper"

GIT_INSTALLED=$(which git)

if [ -z ${GIT_INSTALLED} ]; then
  apt-get install -y git
fi

USERNAME=${USERNAME:-undefined}
USERTOKEN=${USERTOKEN:-undefined}
IMAGE=${IMAGE:-undefined}

if [ ${IMAGE} = "dev" ]; then
  sh -c install_dev.sh ${USERNAME} ${USERTOKEN}
fi