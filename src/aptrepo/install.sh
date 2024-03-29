#!/bin/sh


echo "Activating feature aptrepo"

if [ ! -d "/etc/apt/sources.list.d" ]; then
  mkdir /etc/apt/sources.list.d
fi

SOURCE=${SOURCE:-undefined}

if [ ${SOURCE} = "tsinghua" ]; then
  echo "tsinghua repositry was seleclted"
  cp ./repo/tsinghua /etc/apt/sources.list.d/tsinghua
  echo "Activating feature aptrepo success"
  exit 0
elif [ ${SOURCE} = "ustc" ]; then
  echo "ustc repositry was seleclted"
  cp ./repo/ustc /etc/apt/sources.list.d/ustc
  echo "Activating feature aptrepo success"
  exit 0
elif [ ${SOURCE} = "aliyun" ]; then
  echo "aliyun repositry was seleclted"
  cp ./repo/aliyun /etc/apt/sources.list.d/aliyun
  echo "Activating feature aptrepo success"
  exit 0
else  
  echo "Unkown repository: ${SOURCE}"
  echo "Activating feature aptrepo failed"
  exit 1
fi