#
#
#

function environmentLastStarted() {
    # $1 command
    #       GET     return last started environment
    #       ADD     add environment ($2) as last started environment
    #       DEL     delte environment ($2) from last started environment list
    #       REN     rename environment ($2 as $3) from last started environment list
    local ACTION=$1
    local ENV_NAME=$2
    local CFG_FILE=$CDIR/data/.last-started

    if [ "$ACTION" == "GET" ]; then
        # return last started environment
        echo $(tail -1 $CFG_FILE)
    elif [ "$ACTION" == "ADD" ]; then
        sed -i "/^$ENV_NAME$/d" $CFG_FILE
        echo "$ENV_NAME" >> $CFG_FILE
    elif [ "$ACTION" == "DEL" ]; then
        sed -i "/^$ENV_NAME$/d" $CFG_FILE
    elif [ "$ACTION" == "REN" ]; then
        local $ENV_NEWNAME=$3
        sed -i "s/^$ENV_NAME$/$ENV_NEWNAME/g" $CFG_FILE
    else
        echo "environmentLastStarted invalid action ($ACTION)"
        exit 1
    fi
}

function environmentLastCreated() {
    # $1 command
    #       GET     return last created environment
    #       ADD     add environment ($2) as last created environment
    #       DEL     delete environment ($2) from last created environment list
    #       REN     rename environment ($2 as $3) from last created environment list
    local ACTION=$1
    local ENV_NAME=$2
    local CFG_FILE=$CDIR/data/.last-created

    if [ "$ACTION" == "GET" ]; then
        # return last created environment
        echo $(tail -1 $CFG_FILE)
    elif [ "$ACTION" == "ADD" ]; then
        echo "$ENV_NAME" >> $CFG_FILE
    elif [ "$ACTION" == "DEL" ]; then
        sed -i "/^$ENV_NAME$/d" $CFG_FILE
    elif [ "$ACTION" == "REN" ]; then
        local $ENV_NEWNAME=$3
        sed -i "s/^$ENV_NAME$/$ENV_NEWNAME/g" $CFG_FILE
    else
        echo "environmentLastCreated: invalid action ($ACTION)"
        exit 1
    fi
}


function environmentPathName() {
    # return full path for environment $1
    local ENV_NAME=$1
    echo "$CDIR/environments/$ENV_NAME"
}

function environmentConfigFile() {
    # return full path configuration file name for environment $1
    local ENV_NAME=$1
    echo "$(environmentPathName $ENV_NAME)/.config"
}


function environmentCheckName() {
    # check environment name $1
    #
    # 1: is empty
    # 2: exists
    # 3: do not exists
    # 4: is not valid (allowed characters: "A"-"Z", "0"-"9", "_")
    local ENV_NAME=$1

    if [ "$ENV_NAME" == "" ]; then
        return 1
    elif [[ "$ENV_NAME" =~ ^[a-z0-9_]+$ ]]; then
        if [ -d $(environmentPathName $ENV_NAME) ]; then
            return 2
        else
            return 3
        fi
    else
        return 4
    fi
}


function environmentCreate() {
    # create environment
    # $1 = name
    # $2 = source path/url
    # $3 = data path
    #
    # - create directories
    # - create defaults files
    # - clone git repo, if needed
    # - update data/env file
    local OPT_QUIET=
    local ENV_NAME=$1
    local KRITA_SRC=$2
    local DATA_PATH=$3
    local KBUILDER_VERSION=$4
    local ENV_PATH="$(environmentPathName $ENV_NAME)"
    local CFG_FILE="$(environmentConfigFile $ENV_NAME)"
    local DIRECTORIES=("$ENV_PATH/appimages"
                       "$ENV_PATH/sources/downloads"
                       "$ENV_PATH/sources/krita"
                       "$ENV_PATH/data-env"
                       "$ENV_PATH/workspace/deps/usr"
                       "$ENV_PATH/workspace/krita.appdir/usr"
                       "$ENV_PATH/workspace/krita-build"
                       "$ENV_PATH/.docker-config/mc"
                       "$ENV_PATH/.docker-config/htop"
                       )

    # -- create directories
    for DIRECTORY in ${DIRECTORIES[@]}; do
        displayStep "Create directory $DIRECTORY"
        mkdir -p $DIRECTORY || return 1
        displayOk
    done

    if [ "$DATA_PATH" == "@NONE" ]; then
        DATA_PATH=""
    fi

    # -- create default files
    echo "KRITA_SRC=$KRITA_SRC" > $CFG_FILE
    echo "DATA_PATH=$DATA_PATH" >> $CFG_FILE
    echo "QT_SCALE_FACTOR=1.0" >> $CFG_FILE
    echo "BUILD_KBUILDER=$KBUILDER_VERSION" >> $CFG_FILE
    echo "BUILD_DATE=$(date +'%Y-%m-%d')" >> $CFG_FILE
    echo "BUILD_TIME=$(date +'%H:%M:%S')" >> $CFG_FILE

    if [[ "$KRITA_SRC" =~ ^https?:// ]]; then
        displayStep "Clone remote Krita git repository"
        if [ $OPT_VERBOSE -le 1 ]; then
            OPT_QUIET=-q
        else
            displayNfo ""
        fi

        git clone $OPT_QUIET $KRITA_SRC $ENV_PATH/sources/krita

        if [ $? -ne 0 ]; then
            if [ $OPT_VERBOSE -eq 1 ]; then
                displayKo
            fi
            return 1
        elif [ $OPT_VERBOSE -eq 1 ]; then
            displayOk
        fi
    else
        displayStep "Use local Krita source files"
        displayOk
    fi

    environmentLastCreated ADD $ENV_NAME

    return 0
}


function environmentCleanup() {
    # remove an environment
    # $1 = name
    local ENV_NAME=$1
    local ENV_PATH="$(environmentPathName $ENV_NAME)"

    # -- remove directory
    displayStep "Remove directories"
    rm -rf $ENV_PATH || return 1
    environmentLastCreated DEL $ENV_NAME
    environmentLastStarted DEL $ENV_NAME
    displayOk
    return 0
}


function environmentRename() {
    # rename an environment
    # $1 = old name
    # $2 = new name
    local ENV_OLDNAME=$1
    local ENV_NEWNAME=$2
    local ENV_OLDPATH="$(environmentPathName $ENV_OLDNAME)"
    local ENV_NEWPATH="$(environmentPathName $ENV_NEWNAME)"

    # -- remove directory
    displayStep "Rename directory"
    mv $ENV_OLDPATH $ENV_NEWPATH || return 1
    environmentLastCreated REN $ENV_OLDNAME $ENV_NEWNAME
    environmentLastStarted REN $ENV_OLDNAME $ENV_NEWNAME
    displayOk
    return 0
}


function environmentList() {
    local LIST=($(ls -1 $CDIR/environments))
    echo ${LIST[@]}
}
