#!/bin/sh

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


FEATURE_NAME=$1

if test -z $FEATURE_NAME
then
echo "\033[31mFatal: empty feature name\033[0m"
exit 1
fi

if [ -d "src/${FEATURE_NAME}" ]; then
echo "\033[31mFatal: feature already exist\033[0m"
exit 1
else
exec_cmd_fatal mkdir src/${FEATURE_NAME}
fi

DEVCONTAINER_FEATURE_FILE=src/${FEATURE_NAME}/devcontainer-feature.json
INSTALL_SHELL_SCRIPT=src/${FEATURE_NAME}/install.sh
BASE_SHELL_SCRIPT=src/${FEATURE_NAME}/base.sh



exec_cmd_fatal touch $DEVCONTAINER_FEATURE_FILE
exec_cmd_fatal touch $INSTALL_SHELL_SCRIPT
exec_cmd_fatal chmod +x $INSTALL_SHELL_SCRIPT
exec_cmd_fatal touch $BASE_SHELL_SCRIPT
exec_cmd_fatal chmod +x $BASE_SHELL_SCRIPT

tee $DEVCONTAINER_FEATURE_FILE >>/dev/null << EOF
{
  // Required, must be unique in the context of the repository where the feature 
  // exists and must match the name of the directory where the devcontainer-feature.json 
  // resides
  "id": "${FEATURE_NAME}", 
  // Required: A “human-friendly” display name for the Feature.
  "name": "${FEATURE_NAME}",
  // Required: The semantic version of the Feature (e.g: 1.0.0).
  "version": "1.0.0",
  // Description of the Feature.
  "description": "",
  // Url that points to the documentation of the Feature.
  "documentationURL":"",
  // Url that points to the license of the Feature.
  "licenseURL":"",
  // List of strings relevant to a user that would search for this definition/Feature.
  "keywords":[],
  // A map of options that will be passed as environment variables to the execution of the 
  // script.
  "options":{},
  // A set of name value pairs that sets or overrides environment variables.
  "containerEnv":{},
  // Sets privileged mode for the container (required by things like docker-in-docker) when 
  // the feature is used
  "privileged":false,
  // Adds the tiny init process to the container (--init) when the Feature is used.
  "init": false,
  // Adds container capabilities when the Feature is used.
  "capAdd": [],
  // Sets container security options like updating the seccomp profile when the Feature is used.
  "securityOpt":[],
  // Set if the feature requires an “entrypoint” script that should fire at container start up.
  "entrypoint": "",
  // Product specific properties, each namespace under customizations is treated as a separate 
  // set of properties. For each of this sets the object is parsed, values are replaced while 
  // arrays are set as a union.
  "customizations": {},
  // An object (**) of Feature dependencies that must be satisified before this Feature is installed.
  "dependsOn":{},
  // Array of ID’s of Features (omitting a version tag) that should execute before this one.
  "installsAfter": [],
  // Array of old IDs used to publish this Feature. The property is useful for renaming a currently
  // published Feature within a single namespace.
  "legacyIds": [],
  // Indicates that the Feature is deprecated, and will not receive any further updates/support.
  "deprecated": false,
  // Defaults to unset. Cross-orchestrator way to add additional mounts to a container. 
  "mounts":{},
  // Commands to execute after the container is created. For each lifecycle hook,
  // each command contributed by a Feature is executed in sequence 
  // (blocking the next command from executing). Commands provided by Features are always executed 
  // before any user-provided lifecycle commands. If a Feature provides a given command with 
  // the object syntax, all commands within that group are executed in parallel, but still blocking 
  // commands from subsequent Features and/or the devcontainer.json.
  "onCreateCommand":"",
  // Commands to execute when the container starts
  "updateContentCommand":"",
  // Commands to execute before and after the container is created
  "postCreateCommand":"",
  // Commands to execute before and after the container starts
  "postStartCommand":"",
  // Command to execute after attaching the container to the VS Code instance.
  "postAttachCommand":""
}
EOF

tee $INSTALL_SHELL_SCRIPT >>/dev/null <<- 'EOF' -
#!/bin/sh

###############################################################################
#                                 Functions                                   #
###############################################################################

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

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
#                         options
###############################################################################



###############################################################################
#                     custom script code
###############################################################################

EOF




