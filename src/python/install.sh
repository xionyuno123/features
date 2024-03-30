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

compare_versions() {
    ver1=$1
    ver2=$2
    if [[ $ver1 == $ver2 ]]; then
        return 0
    elif [[ $ver1 > $ver2 ]]; then
        return 1
    else
        return 2
    fi
}

VERSION=${VERSION:-undefined}
WGET_INSTALLED=$(which wget)

check_version_format $VERSION
compare_versions $VERSION "3.0.0"

PYTHON3=$?

if [ -z ${WGET_INSTALLED} ]; then
  apt-get install -y wget
fi

wget https://registry.npmmirror.com/-/binary/python/${VERSION}/Python-${VERSION}.tgz && tar -xvf Python-${VERSION}.tgz && cd Python-${VERSION}

if [ $? != 0 ]; then 
    exit 1
fi

if [ $PYTHON3 <= 1 ]; then 
    ./configure --prefix=/usr/local/python3
else 
    ./configure --prefix=/usr/local/python
fi

if [ $? != 0]; then
    exit 1
fi

make -j `nproc` && make install

if [ $? != 0]; then
    exit 1
fi

if [ $PYTHON3 <= 1 ]; then 
    ln -s /usr/local/python3/bin/python3 /usr/bin/python3 & ln -s /usr/local/python3/bin/pip3 /usr/bin/pip3
else 
    ln -s /usr/local/python/bin/python /usr/bin/python & ln -s /usr/local/python/bin/pip /usr/bin/pip
fi

if [ $? != 0]; then
    exit 1
fi

cd ../ && rm Python-${VERSION} -rf && rm Python-${VERSION}.tgz 