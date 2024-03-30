#!/bin/bash


echo "Activating feature cityhash"

GIT_INSTALLED=$(which git)

if [ -z ${GIT_INSTALLED} ]; then
  apt-get install -y git
fi

USERNAME=${USERNAME:-undefined}
USERTOKEN=${USERTOKEN:-undefined}

git clone https://${USERNAME}:${USERTOKEN}@e.coding.net/g-pxye7583/xtools/cityhash.git \
&& cd cityhash \
&& ./configure --enable-sse4.2 \ 
&& make all check CXXFLAGS="-g -O3 -msse4.2" \ && 
make install && cd .. && rm cityhash -rf