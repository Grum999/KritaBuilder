#
#
#

if groups | grep docker > /dev/null 2>&1; then
    DOCKER_BINARY=docker
else
    DOCKER_BINARY="sudo docker"
fi

# docker src directory
CDCKDIR="$CDIR/data/src-docker"


# app image internal paths
APPIMG_USER_HOME=/home/appimage
APPIMG_KRITA_WS_PATH=$APPIMG_USER_HOME/build/appimage-workspace
APPIMG_KRITA_SRC_PATH=$APPIMG_USER_HOME/build/src/krita
APPIMG_KRITA_APPIMG_PATH=$APPIMG_USER_HOME/build/appimages


# ---

source ${CINCDIR}/environments.inc



function dockerImageCreate() {
    # create docker image
    #
    # $1 image name
    # $2 option for cache
    local ENV_NAME=$1
    local OPT_NO_CACHE=
    local OPT_QUIET=
    local REDIRECT=1

    if [ $2 -eq 1 ]; then
        OPT_NO_CACHE=--no-cache
    fi

    displayStep "Create docker image"

    if [ $OPT_VERBOSE -le 1 ]; then
        OPT_QUIET=-q
        REDIRECT=/dev/null
    else
        displayNfo ""
    fi

    ${DOCKER_BINARY} image build $OPT_NO_CACHE $OPT_QUIET \
                                 -t $ENV_NAME \
                                 --build-arg APPIMAGE_UID=$(id -u) \
                                 --build-arg APPIMAGE_GID=$(id -g) \
                                 $CDCKDIR 1>&$REDIRECT

    if [ $? -ne 0 ]; then
        if [ $OPT_VERBOSE -eq 1 ]; then
            displayKo
        fi
        return 1
    elif [ $OPT_VERBOSE -eq 1 ]; then
        displayOk
    fi

    return 0
}

function dockerImageCleanup() {
    # remove docker image
    #
    # $1 image name
    local ENV_NAME=$1
    local REDIRECT=1

    displayStep "Cleanup docker image"

    IMAGE_ID=$(${DOCKER_BINARY} image ls --filter reference=$ENV_NAME -q -a)

    if [[ "$IMAGE_ID" != "" ]]; then

        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} image rm -f $ENV_NAME 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        display "N/A"
    fi

    return 0
}

function dockerImageRename() {
    # rename docker image
    #
    # $1 old image name
    # $2 new image name
    local ENV_OLDNAME=$1
    local ENV_NEWNAME=$2
    local REDIRECT=1

    displayStep "Rename docker image ($ENV_OLDNAME -> $ENV_NEWNAME)"

    IMAGE_ID=$(${DOCKER_BINARY} image ls --filter reference=$ENV_OLDNAME -q -a)

    if [[ "$IMAGE_ID" != "" ]]; then

        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} image tag $ENV_OLDNAME $ENV_NEWNAME 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        fi

        ${DOCKER_BINARY} image rm -f $ENV_OLDNAME 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        display "N/A"
    fi

    return 0
}

function dockerContainerIsRunning() {
    # return 1 if docker container for environment is running, otherwise 0
    #
    # $1 environment name
    local ENV_NAME=$1

    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_NAME$ --filter status=running -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then
        return 1
    fi

    return 0
}

function dockerContainerExists() {
    # return 1 if docker container for environment exists, otherwise 0
    #
    # $1 environment name
    local ENV_NAME=$1

    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_NAME$ -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then
        return 1
    fi

    return 0
}

function dockerContainerRun() {
    # start docker image
    #
    # $1 environment name=image name
    # $2 set to 1 to display env name
    # $3 set to 1 to not stop a running docker (cancel action if already running)
    local ENV_NAME=$1
    local ENV_NAME_DISPLAY=$2
    local ENV_DONOT_RESTART=$3
    local ENV_PATH=$(environmentPathName $ENV_NAME)
    local CFG_FILE="$(environmentConfigFile $ENV_NAME)"
    local DOCKER_MOUNTS="-v $ENV_PATH/workspace/:$APPIMG_KRITA_WS_PATH:rw"
    local DOCKER_ENV=
    local REDIRECT=1
    local NVIDIA_OPTS=
    local OPT_QUIET=
    local OPT_KVM=

    source $CFG_FILE

    if [[ -e /dev/kvm ]]; then
        OPT_KVM+="--device /dev/kvm"
    fi

    DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/data-env:$APPIMG_USER_HOME/data-env:rw"
    DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/appimages:$APPIMG_KRITA_APPIMG_PATH:rw"
    DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/.docker-config:$APPIMG_USER_HOME/.config:rw"
    DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/.docker-local:$APPIMG_USER_HOME/.local:rw"

    if [ "$DATA_PATH" != "" ]; then
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v $DATA_PATH:$APPIMG_USER_HOME/data:rw"
    fi

    if [[ -d $ENV_PATH/sources/downloads ]]; then
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/sources/downloads:$APPIMG_KRITA_WS_PATH/downloads:rw"
    fi

    if [[ -d $KRITA_SRC ]]; then
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v $KRITA_SRC:$APPIMG_KRITA_SRC_PATH:rw"
    else
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v $ENV_PATH/sources/krita:$APPIMG_KRITA_SRC_PATH:rw"
    fi

    if [[ -e /dev/nvidiactl ]]; then
        NVIDIA_OPTS+="--device /dev/nvidia0 --device /dev/nvidiactl --device /dev/nvidia-uvm"
    fi

    dockerContainerIsRunning $ENV_NAME
    if [ $? -eq 1 ]; then
        if [ "$ENV_DONOT_RESTART" != "1" ]; then
            displayStep "Start docker container ($ENV_NAME)"
            display "N/A (already running)"
            return 0
        fi
        dockerContainerStop $ENV_NAME || return 1
        dockerContainerCleanup $ENV_NAME || return 1
    else
        $(dockerContainerCleanup $ENV_NAME) 1&>/dev/null
    fi

    dockerContainerCreatePulseaudioSocket
    if [ $? -eq 1 ]; then
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v /tmp/pulseaudio-docker.socket:/tmp/pulseaudio-docker.socket"
        DOCKER_MOUNTS="$DOCKER_MOUNTS -v /tmp/pulseaudio.client.conf:/etc/pulse/client.conf"
        DOCKER_ENV="$DOCKER_ENV --env PULSE_SERVER=unix:/tmp/pulseaudio-docker.socket"
        DOCKER_ENV="$DOCKER_ENV --env PULSE_COOKIE=/tmp/pulseaudio-docker.cookie"
    fi

    if [ "$ENV_NAME_DISPLAY" == "1" ]; then
        displayStep "Start docker container ($ENV_NAME)"
    else
        displayStep "Start docker container"
    fi

    if [ $OPT_VERBOSE -le 1 ]; then
        OPT_QUIET=-q
        REDIRECT=/dev/null
    else
        displayNfo ""
    fi

    ${DOCKER_BINARY} container run -P -t -d \
    $DOCKER_MOUNTS \
    -v /tmp/.X11-unix/:/tmp/.X11-unix \
    -v $XAUTHORITY:$APPIMG_USER_HOME/.Xauthority:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -e DISPLAY \
    -e XAUTHORITY \
    -e TERM=$TERM \
    -h $HOSTNAME \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --security-opt label=type:container_runtime_t \
    --device /dev/dri \
    $NVIDIA_OPTS \
    $DOCKER_ENV \
    $OPT_KVM \
    --name $ENV_NAME \
    $ENV_NAME 1>&$REDIRECT

    if [ $? -ne 0 ]; then
        if [ $OPT_VERBOSE -eq 1 ]; then
            displayKo
        fi
        return 1
    elif [ $OPT_VERBOSE -eq 1 ]; then
        displayOk
    fi

    return 0
}

function dockerContainerCleanup {
    # cleanup docker container for environment
    #
    # $1 environment name=image name
    # $2 filter status
    local ENV_NAME=$1
    local FILTER_STATUS=$2
    local REDIRECT=1

    if [ "$FILTER_STATUS" != "" ]; then
        FILTER_STATUS="--filter status=$FILTER_STATUS"
    fi

    displayStep "Cleanup docker container"

    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_NAME$ $FILTER_STATUS -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then

        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} container rm -f $CONTAINER_ID 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        display "N/A"
    fi

    return 0
}

function dockerContainerStop {
    # stop docker container for environment
    #
    # $1 environment name=image name
    # $2 set to 1 to display env name
    local ENV_NAME=$1
    local ENV_NAME_DISPLAY=$2
    local REDIRECT=1

    if [ "$ENV_NAME_DISPLAY" == "1" ]; then
        displayStep "Stop docker container ($ENV_NAME)"
    else
        displayStep "Stop docker container"
    fi

    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_NAME$ --filter status=running -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then
        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} container stop $CONTAINER_ID 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        display "N/A (already stopped)"
    fi

    return 0
}

function dockerContainerStart {
    # start docker container for environment
    #
    # $1 environment name=image name
    # $2 set to 1 to display env name
    local ENV_NAME=$1
    local ENV_NAME_DISPLAY=$2
    local REDIRECT=1

    if [ "$ENV_NAME_DISPLAY" == "1" ]; then
        displayStep "Start docker container ($ENV_NAME)"
    else
        displayStep "Start docker container"
    fi

    dockerContainerIsRunning $ENV_NAME
    if [ $? -eq 1 ]; then
        display "N/A (already running)"
        return 0
    fi

    dockerContainerExists $ENV_NAME
    if [ $? -eq 0 ]; then
        dockerContainerRun $ENV_NAME 0 1
        return $?
    fi


    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_NAME$ --filter status=exited -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then
        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} container start $CONTAINER_ID 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    fi

    return 0
}

function dockerContainerCreatePulseaudioSocket {
    local REDIRECT=1

    if [ $OPT_VERBOSE -eq 2 ]; then
        displayStep "Creating a pulseaudio socket"
    fi

    if [[ ! -e /tmp/pulseaudio-docker.socket ]]; then
        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        pactl load-module module-native-protocol-unix socket=/tmp/pulseaudio-docker.socket 1>&$REDIRECT

        if [ $? -eq 0 ]; then
        cat <<EOF > /tmp/pulseaudio.client.conf
default-server = unix:/tmp/pulseaudio-docker.socket
# Prevent a server running in the container
autospawn = no
daemon-binary = /bin/true
# Prevent the use of shared memory
enable-shm = false
EOF
            if [ $OPT_VERBOSE -eq 2 ]; then
                displayOk
            fi
        else
            if [ $OPT_VERBOSE -eq 2 ]; then
                displayKo
            fi
            return 1
        fi
    else
        if [ $OPT_VERBOSE -eq 2 ]; then
            display "N/A (already exists)"
        fi
    fi
    return 0
}

function dockerContainerRename() {
    # rename container
    #
    # $1 old container name
    # $2 new container name
    local ENV_OLDNAME=$1
    local ENV_NEWNAME=$2
    local REDIRECT=1

    displayStep "Rename container ($ENV_OLDNAME -> $ENV_NEWNAME)"

    CONTAINER_ID=$(${DOCKER_BINARY} container ls --filter name=^$ENV_OLDNAME$ -q -a)

    if [[ "$CONTAINER_ID" != "" ]]; then

        if [ $OPT_VERBOSE -le 1 ]; then
            REDIRECT=/dev/null
        else
            displayNfo ""
        fi

        ${DOCKER_BINARY} container rename $ENV_OLDNAME $ENV_NEWNAME 1>&$REDIRECT

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        display "N/A"
    fi

    return 0
}

function dockerContainerStats() {
    # display container stats
    #
    # $1 environment name
    local ENV_NAME=$1

    ${DOCKER_BINARY} container stats $ENV_NAME
}

function dockerContainerExec() {
    # execute a command on a container
    #
    ${DOCKER_BINARY} container exec $@
}
