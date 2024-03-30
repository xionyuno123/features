#!/bin/bash


echo "Activating feature python"

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

# mpi 并行计算库 
# libicu 支持正则表达式的unicode字符集
# libbz2 与bzip2有关的数据压缩库
apt-get install -y mpi-default-dev libicu-dev libbz2-dev \
&& git clone -b boost-${VERSION} https://gitee.com/mirrors/boost.git \
&& cd boost \
&& ./bootstrap.sh && echo "using mpi ;" >> project-config.jam \
&& ./bootstrap.sh --show-libraries && ./b2 && ./b2 install && cd .. && rm boost -rf