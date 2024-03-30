#!/bin/bash


echo "Activating feature glog"

check_version_format() {
    version=$1
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Installing python $1"
    else
        echo "Invalid version string '$1'"
        exit 1
    fi
}

VERSION=${VERSION:-undefined}
GIT_INSTALLED=$(which git)

check_version_format $VERSION

if [ -z ${GIT_INSTALLED} ]; then
  apt-get install -y git
fi

git clone -b v${VERSION} https://gitee.com/mirrors/glog.git && cd glog && cmake -S . -B build -G "Unix Makefiles" && cd build \ 
&& make -j `nproc` && make install && cd .. && cd .. && rm glog -rf