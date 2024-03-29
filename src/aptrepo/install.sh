#!/bin/sh


echo "Activating feature aptrepo"

SOURCE=${SOURCE:-undefined}

if [ ${SOURCE} = "tsinghua" ]; then
  echo "tsinghua repositry was seleclted"
  sed -i "s/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g" /etc/apt/sources.list
elif [ ${SOURCE} = "ustc" ]; then
  echo "ustc repositry was seleclted"
  sed -i "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g" /etc/apt/sources.list
elif [ ${SOURCE} = "aliyun" ]; then
  echo "aliyun repositry was seleclted"
  sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list
else  
  echo "Unkown repository: ${SOURCE}"
  echo "Activating feature aptrepo failed"
  exit 1
fi

apt-get clean 
apt-get update

echo "Activating feature aptrepo success"