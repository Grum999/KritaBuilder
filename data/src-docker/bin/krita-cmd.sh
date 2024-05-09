#!/bin/bash

source ~/.bash_devenv

EXECTIME_FILE=$KRITA_BUILD_PATH/.exectime
BUILDLOG_FILE=$KRITA_BUILD_PATH/.buildlog
OUTLOG_FILE=$KRITA_BUILD_PATH/.outlog
GETLOG_FILE=/tmp/getlog
GITNFO_FILE=$KRITA_BUILD_PATH/.gitnfo

function gitNfo() {
    GITNFO=$(git -C $KRITA_SRC_PATH log --format="$1: %D%n            %h -- %ai%n            %s" HEAD^..HEAD)
    IFS=$'\n'
    for nfo in $GITNFO
    do
        buildLog $nfo
    done

    git -C $KRITA_SRC_PATH log --format="%D%n%h -- %ai%n%s" HEAD^..HEAD > $GITNFO_FILE
}

function buildGitNfo() {
    cat $GITNFO_FILE
}

function buildLogStart() {
    echo -n "" > $BUILDLOG_FILE
    echo -n "" > $OUTLOG_FILE
}

function buildLogGet() {
    local MODE=$1
    local TIME=$2
    local VIEW=$3

    if [ "$MODE" == 'short' ]; then
        cat $BUILDLOG_FILE > $GETLOG_FILE
    else
        cat $OUTLOG_FILE > $GETLOG_FILE
    fi

    if [ "$TIME" == 'Y' ]; then
        echo "" >> $GETLOG_FILE
        echo "--- Execution time" >> $GETLOG_FILE
        echo "" >> $GETLOG_FILE
        cat $EXECTIME_FILE >> $GETLOG_FILE
    fi

    if [ "$VIEW" == "cat" ]; then
        cat $GETLOG_FILE
    elif [ "$VIEW" == "emacs" ]; then
        emacs $GETLOG_FILE
    elif [ "$VIEW" == "mcedit" ]; then
        mcedit $GETLOG_FILE
    elif [ "$VIEW" == "nano" ]; then
        nano $GETLOG_FILE
    elif [ "$VIEW" == "vim" ] || [ "$VIEW" == "vi" ]; then
        vim $GETLOG_FILE
    fi
}

function buildLog() {
    echo "$@" >> $BUILDLOG_FILE
    echo "$@" >> $OUTLOG_FILE
}

function execTimeStart() {
    echo -n "" > $EXECTIME_FILE
}

function execTimeGet() {
    cat $EXECTIME_FILE
}

function execTime() {
    local STEP_NAME=
    local STEP_ID=$1
    shift

    case "$STEP_ID" in
        kritaBuildDeps)
            STEP_NAME="Build dependencies"
            ;;
        kritaBuild)
            STEP_NAME="Build Krita"
            ;;
        kritaBuildAppImage)
            STEP_NAME="Build Krita AppImage"
            ;;
    esac

    /usr/bin/time -a -o $EXECTIME_FILE -f "$STEP_NAME\n  real    %es\n  user    %Us\n  system  %Ss\n" -- $@ | tee -a $OUTLOG_FILE
}

function kritaClean() {
    # make clean
    # $1 = option verbose
    local REDIRECT=1
    local OPT_VERBOSE=$1

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    buildLog "kritaClean"

    cd $KRITA_WS_PATH/krita-build
    if [[ -f CMakeCache.txt ]]; then
        buildLog "kritaClean: clean"
        make clean 1>&$REDIRECT || exit 1
        buildLog "kritaClean: done"
    else
        buildLog "kritaClean: skipped"
    fi
}

function kritaCleanSip() {
    # remove SIP tmp data
    # $1 = option verbose
    local REDIRECT=1
    local OPT_VERBOSE=$1

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    buildLog "kritaCleanSip"

    if [[ -d $KRITA_WS_PATH/krita-build/plugins/extensions/pykrita/sip/_tmp ]]; then
        buildLog "kritaCleanSip: clean"
        rm -rfd $KRITA_WS_PATH/krita-build/plugins/extensions/pykrita/sip/_tmp 1>&$REDIRECT || exit 1
        buildLog "kritaCleanSip: done"
    else
        buildLog "kritaCleanSip: skipped"
    fi
}

function kritaCleanDeps() {
    # clean dependencies
    # $1 = option verbose
    local REDIRECT=1
    local OPT_VERBOSE=$1

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    if [[ -d $KRITA_WS_PATH/deps ]]; then
        rm -rfd $KRITA_WS_PATH/deps 1>&$REDIRECT || exit 1
    fi
    if [[ -d $KRITA_WS_PATH/deps-build ]]; then
        rm -rfd $KRITA_WS_PATH/deps-build 1>&$REDIRECT || exit 1
    fi
}

function kritaBuildDeps() {
    # build dependencies
    # $1 = QT_ENABLE_DEBUG_INFO
    # $2 = QT_ENABLE_ASAN
    # $3 = option verbose
    local REDIRECT=1
    local OPT_VERBOSE=$3

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    buildLog "kritaBuildDeps"

    QT_ENABLE_DEBUG_INFO=$1
    QT_ENABLE_ASAN=$2

    buildLog "kritaBuildDeps: QT_ENABLE_DEBUG_INFO=$QT_ENABLE_DEBUG_INFO"
    buildLog "kritaBuildDeps: QT_ENABLE_ASAN=$QT_ENABLE_ASAN"
    buildLog "kritaBuildDeps: KRITA_WS_PATH=$KRITA_WS_PATH"
    buildLog "kritaBuildDeps: KRITA_SRC_PATH=$KRITA_SRC_PATH"

    cd $KRITA_WS_PATH
    execTime kritaBuildDeps $KRITA_SRC_PATH/packaging/linux/appimage/build-deps.sh $KRITA_WS_PATH $KRITA_SRC_PATH 1>&$REDIRECT || exit 1
}

function kritaBuild() {
    # build Krita
    # $1 = OPT_JOBS
    # $2 = option verbose
    # $@ = KRITA_EXTRA_CMAKE_OPTIONS
    local REDIRECT=1

    local OPT_JOBS=$1
    shift
    local OPT_VERBOSE=$1
    shift
    local KRITA_EXTRA_CMAKE_OPTIONS=$@

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    buildLog "kritaBuild"

    buildLog "kritaBuild: KRITA_SRC_PATH=$KRITA_SRC_PATH"
    gitNfo "kritaBuild"

    cd $KRITA_WS_PATH/krita-build
    if [[ ! -f CMakeCache.txt ]]; then
        buildLog "kritaBuild: run cmake"
        buildLog "kritaBuild: KRITA_EXTRA_CMAKE_OPTIONS=$KRITA_EXTRA_CMAKE_OPTIONS"

        $USER_HOME/bin/run_cmake.sh $KRITA_EXTRA_CMAKE_OPTIONS \
                                    $KRITA_SRC_PATH 1>&$REDIRECT || exit 1
    fi

    buildLog "kritaBuild: build"
    execTime kritaBuild make -j$OPT_JOBS install 1>&$REDIRECT
    buildLog "kritaBuild: done"
}

function kritaBuildAppImage() {
    # build appimage
    # $1 = OPT_JOBS
    # $2 = option verbose
    local REDIRECT=1
    local OPT_JOBS=$1
    local OPT_VERBOSE=$2

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    INCLUDE_DEBUG_SYMBOLS=0

    if [ $INCLUDE_DEBUG_SYMBOLS -eq 0 ]; then
        export STRIP_APPIMAGE=1
    fi

    buildLog "kritaBuildAppImage"

    buildLog "kritaBuildAppImage: KRITA_WS_PATH=$KRITA_WS_PATH"
    buildLog "kritaBuildAppImage: KRITA_SRC_PATH=$KRITA_SRC_PATH"
    gitNfo "kritaBuildAppImage"

    buildLog "kritaBuildAppImage: build"
    cd $KRITA_WS_PATH
    execTime kritaBuildAppImage $KRITA_SRC_PATH/packaging/linux/appimage/build-image.sh $KRITA_WS_PATH $KRITA_SRC_PATH 1>&$REDIRECT || exit 2

    APPIMAGE_FILE=$(ls -t -1 $KRITA_WS_PATH/*.appimage)
    APPIMAGE_FILE_BN=$(basename $APPIMAGE_FILE)

    cp $GITNFO_FILE "$KRITA_APPIMG_PATH/$APPIMAGE_FILE_BN.gitNfo"

    buildLog "kritaBuildAppImage: move appimage $APPIMAGE_FILE_BN to $KRITA_APPIMG_PATH"
    mv $APPIMAGE_FILE $KRITA_APPIMG_PATH 1>&$REDIRECT || exit 3

    buildLog "kritaBuildAppImage: cleanup"
    rm -rf $KRITA_WS_PATH/krita.appdir/* 1>&$REDIRECT || exit 4

    # Repopulate build directory...
    buildLog "kritaBuildAppImage: repopulate build directory"
    cd $KRITA_WS_PATH/krita-build
    make -j$OPT_JOBS install/fast > /dev/null || exit 5
    buildLog "kritaBuildAppImage: done"
}

function kritaExec() {
    ARGS=$(getopt -o "s:" -l "scale:" -- "$@")
    eval set -- "$ARGS"

    while true; do
        case "$1" in
            --scale-factor)
                shift
                export QT_SCALE_FACTOR=$1
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done
    krita $@
}


case "$1" in
    buildGitNfo)
        shift
        buildGitNfo $@
        exit $?
        ;;
    buildLogStart)
        buildLogStart
        exit $?
        ;;
    buildLogGet)
        shift
        buildLogGet $@
        exit $?
        ;;
    execTimeGet)
        execTimeGet
        exit $?
        ;;
    execTimeStart)
        execTimeStart
        exit $?
        ;;
    kritaClean)
        shift
        kritaClean $@
        exit $?
        ;;
    kritaCleanSip)
        shift
        kritaCleanSip $@
        exit $?
        ;;
    kritaCleanDeps)
        shift
        kritaCleanDeps $@
        exit $?
        ;;
    kritaBuildDeps)
        shift
        kritaBuildDeps $@
        exit $?
        ;;
    kritaBuild)
        shift
        kritaBuild $@
        exit $?
        ;;
    kritaBuildAppImage)
        shift
        kritaBuildAppImage $@
        exit $?
        ;;
    kritaExec)
        shift
        kritaExec $@
        exit $?
        ;;
esac

exit 1


