#!/bin/bash


echo "Activating feature folly"

GIT_INSTALLED=$(which git)

if [ -z ${GIT_INSTALLED} ]; then
  apt-get install -y git
fi

git clone https://gitee.com/mirrors/folly.git

cd folly

python3 ./build/fbcode_builder/getdeps.py --allow-system-packages build

python3 ./build/fbcode_builder/getdeps.py --allow-system-packages test

cd ..
rm folly -rf