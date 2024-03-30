#!/bin/sh

###############################################################################
#                         options
###############################################################################

FOLLY_VERSION=${VERSION:-undefined}



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
  if [ $? != 0 ]
  then
    echo  "${yellow}Warning: failed to execute command '$cmd' with params '$@',code: $? ${reset}" >&2
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
  if [ $? != 0 ]
  then
    echo  "${red}Fatal: failed to execute command '$cmd' with params '$@',code: $? ${reset}" >&2
    exit $?
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

# Partial version matching
if [ "$(echo "${FOLLY_VERSION}" | grep -o '\.' | wc -l)" != "2" ]; then
    requested_version="${FOLLY_VERSION}"
    version_list="$(curl -X GET --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/mirrors/folly/tags?access_token=4742447bfca33de9fd1d143863c21e65&sort=name&direction=desc&page=1' | grep -oP '"name":\s*"v\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -rV )"
    if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "lts" ] || [ "${requested_version}" = "current" ]; then
        FOLLY_VERSION="$(echo "${version_list}" | head -n 1)"
    else
        set +e
        FOLLY_VERSION="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
        set -e
    fi
fi

echo "Downloading source for ${FOLLY_VERSION}..."
check_packages git
cd /tmp
exec_cmd_fatal git clone --depth 1 -b v${FOLLY_VERSION} https://gitee.com/mirrors/folly.git
echo "Building..."

check_packages libdouble-conversion-dev
check_packages libevent-dev
check_packages libgflags-dev
check_packages libgoogle-glog-dev
check_packages liblz4-dev
check_packages liblzma-dev
check_packages libsnappy-dev
check_packages libsodium-dev
check_packages libtool
check_packages libzstd-dev
check_packages ninja-build
check_packages autoconf
check_packages automake
check_packages python3
check_packages python3-pip
check_packages libfmt-dev

exec_cmd_fatal cd folly
exec_cmd_fatal mkdir _build
exec_cmd_fatal cd _build
exec_cmd_fatal cmake ..
exec_cmd_fatal make -j `nproc`
exec_cmd_fatal make install
exec_cmd_fatal cd /tmp
exec_cmd_fatal rm /tmp/folly -rf
clean_up
echo "Done!"