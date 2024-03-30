#!/bin/sh

./base.sh

if [ $? != 0 ]; then
  exit $?
fi

###############################################################################
#                         options
###############################################################################
CMAKE_VERSION=${VERSION:-undefined}
CMAKE_REPO="https://gitee.com/mirrors/CMake.git"

###############################################################################
#                     custom script code
###############################################################################

if [ ${CMAKE_VERSION} = "os-provided" ] || [ ${CMAKE_VERSION} = "system" ]; then
  if type cmake >/dev/null 2>&1; then
      echo "Detected existing system install: $(cmake --version)"
      clean_up
      exit 0
  fi

  if [ "$INSTALL_CMD" = "apt-get" ]; then
      echo "Installing git from OS apt repository"
  else
      echo "Installing git from OS yum/dnf repository"
  fi

  if [ $ID = "mariner" ]; then
        check_packages ca-certificates
  fi

  check_packages cmake
  clean_up
  exit 0
fi

# Partial version matching
if [ "$(echo "${CMAKE_VERSION}" | grep -o '\.' | wc -l)" != "2" ]; then
    requested_version="${CMAKE_VERSION}"
    version_list="$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/mirrors/CMake/tags?access_token=4742447bfca33de9fd1d143863c21e65&sort=name&direction=desc&page=1'| grep -oP '"name":\s*"v\K[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -rV )"
    if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "lts" ] || [ "${requested_version}" = "current" ]; then
        CMAKE_VERSION="$(echo "${version_list}" | head -n 1)"
    else
        set +e
        CMAKE_VERSION="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
        set -e
    fi
fi


echo "Downloading source for ${CMAKE_VERSION}..."
cd /tmp
exec_cmd_fatal git clone -b v${CMAKE_VERSION} https://gitee.com/mirrors/CMake.git
cd /tmp/CMake
echo "Building..."
exec_cmd_fatal ./bootstrap 
exec_cmd_fatal make -j `nproc`
exec_cmd_fatal make install
exec_cmd_fatal rm /tmp/CMake -rf
clean_up
echo "Done!"


