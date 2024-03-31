#!/bin/sh

###############################################################################
#                         options
###############################################################################

BOOST_VERSION=${VERSION:-undefined}



###############################################################################
#                                 Functions                                   #
###############################################################################
# if [ "$(id -u)" -ne 0 ]; then
#     echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
#     exit 1
# fi

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
    VERSION_CODENAME="${ID}{$VERSION_ID}"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

if type apt-get > /dev/null 2>&1; then
    INSTALL_CMD=apt-get
elif type microdnf > /dev/null 2>&1; then
    INSTALL_CMD=microdnf
elif type dnf > /dev/null 2>&1; then
    INSTALL_CMD=dnf
elif type yum > /dev/null 2>&1; then
    INSTALL_CMD=yum
else
    echo "(Error) Unable to find a supported package manager."
    exit 1
fi

clean_up() {
    case $ADJUSTED_ID in
        debian)
            rm -rf /var/lib/apt/lists/*
            ;;
        rhel)
            rm -rf /var/cache/dnf/*
            rm -rf /var/cache/yum/*
            ;;
    esac
}

pkg_mgr_update() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            ${INSTALL_CMD} update -y
        fi
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        if [ "$(find /var/cache/${INSTALL_CMD}/* | wc -l)" = "0" ]; then
            echo "Running ${INSTALL_CMD} check-update ..."
            ${INSTALL_CMD} check-update
        fi
    fi
}

exec_cmd_warning() {
  yellow='\033[33m'
  reset='\033[0m' 
  cmd=$1
  shift
  $cmd $@
  res=$?
  if [ $res != 0 ]
  then
    echo  "${yellow}Warning: failed to execute command '$cmd' with params '$@',code: $res ${reset}" >&2
  else
    echo  "Info: execute command '$cmd' with params '$@' success"
  fi
}

exec_cmd_fatal() {
  red='\033[31m'
  reset='\033[0m' 
  cmd=$1
  shift
  $cmd $@
  res=$?
  if [ $res != 0 ]
  then
    echo  "${red}Fatal: failed to execute command '$cmd' with params '$@',code: $res ${reset}" >&2
    exit 1
  else
    echo  "Info: execute command '$cmd' with params '$@' success"
  fi
}

is_null_string() {
  if [ -z $1 ]
  then 
    return 1
  else
    return 0
  fi
}

is_undefined() {
  if [ -v $1 ]
  then 
    return 0
  else 
    return 1
  fi
}

is_number() {
  if [[ $1 =~ ^[0-9]+$ ]]
  then
    return 1
  else 
    return 0
  fi
}

is_installed() {
  if which $1 > /dev/null
  then
    return 0
  else 
    return 1
  fi
}

check_packages() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if ! dpkg -s "$@" > /dev/null 2>&1; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install --no-install-recommends "$@"
        fi
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        _num_pkgs=$(echo "$@" | tr ' ' \\012 | wc -l)
        _num_installed=$(${INSTALL_CMD} -C list installed "$@" | sed '1,/^Installed/d' | wc -l)
        if [ ${_num_pkgs} != ${_num_installed} ]; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install "$@"
        fi
    elif [ ${INSTALL_CMD} = "microdnf" ]; then
        ${INSTALL_CMD} -y install \
            --refresh \
            --best \
            --nodocs \
            --noplugins \
            --setopt=install_weak_deps=0 \
            "$@"
    else
        echo "Linux distro ${ID} not supported."
        exit 1
    fi
}
###############################################################################
#                     custom script code
###############################################################################
if [ ${BOOST_VERSION} = "os-provided" ] || [ ${BOOST_VERSION} = "system" ]; then
  exec_cmd_fatal touch /tmp/test.cpp
  exec_cmd_fatal tee "/tmp/test.cpp" > /dev/null << EOF
#include<iostream>
#include<boost/bind/bind.hpp>
#include<boost/version.hpp>
using namespace std;
using namespace boost::placeholders;
int fun(int x,int y){return x+y;}
int main(){
int m=1;int n=2;
boost::bind(fun,_1,_2)(m,n);
cout << BOOST_LIB_VERSION << endl;
return 0;
}
EOF
  
  g++ /tmp/test.cpp -o /tmp/test

  if [ $? == 0 ]; then
    echo "Detected existing boost install: $(/tmp/test)"
    clean_up
    rm /tmp/test.cpp
    rm /tmp/test
    exit 0
  fi 

  if [ "$INSTALL_CMD" = "apt-get" ]; then
      echo "Installing boost from OS apt repository"
  else
      echo "Installing boost from OS yum/dnf repository"
  fi

  if [ $ID = "mariner" ]; then
        check_packages ca-certificates
  fi

  check_packages libboost-all-dev
  clean_up
  exit 0
fi


# Partial version matching
if [ "$(echo "${BOOST_VERSION}" | grep -o '\.' | wc -l)" != "2" ]; then
    requested_version="${BOOST_VERSION}"
    version_list="$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/mirrors/boost/tags?access_token=7dcd0f978a55cf88a14ffd398d4d3be3&sort=name&direction=desc&page=1' | grep -oP '"name":\s*"boost-\K[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -rV )"
    if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "lts" ] || [ "${requested_version}" = "current" ]; then
        BOOST_VERSION="$(echo "${version_list}" | head -n 1)"
    else
        set +e
        BOOST_VERSION="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
        set -e
    fi
fi

echo "Downloading source for ${BOOST_VERSION}..."
major=$(echo $BOOST_VERSION | cut -d. -f1)
minor=$(echo $BOOST_VERSION | cut -d. -f2)
patch=$(echo $BOOST_VERSION | cut -d. -f3)

check_packages wget
cd /tmp
wget https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${major}_${minor}_${patch}.tar.gz
echo "Building..."
check_packages mpi-default-dev
check_packages libicu-dev
check_packages libbz2-dev
exec_cmd_fatal cd boost_${major}_${minor}_${patch}
exec_cmd_fatal ./bootstrap.sh --with-libraries=all --with-toolset=gcc
exec_cmd_fatal echo "using mpi ;" >> project-config.jam
exec_cmd_fatal ./bootstrap.sh --show-libraries
exec_cmd_fatal ./b2
exec_cmd_fatal ./b2 install
exec_cmd_fatal cd /tmp
exec_cmd_fatal rm /tmp/boost_${major}_${minor}_${patch} -rf
exec_cmd_fatal rm /tmp/boost_${major}_${minor}_${patch}.tar.gz
clean_up
echo "Done!"

