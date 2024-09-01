#!/bin/bash

source ~/.bash_devenv

EXECTIME_FILE=$KRITA_BUILD_PATH/.exectime
BUILDLOG_FILE=$KRITA_BUILD_PATH/.buildlog
OUTLOG_FILE=$KRITA_BUILD_PATH/.outlog
GETLOG_FILE=/tmp/getlog
GITNFO_FILE=$KRITA_BUILD_PATH/.gitnfo
DEBUGLOG_FILE=$KRITA_BUILD_PATH/.debug-output

function buildGitNfo() {
    GITNFO=$(git -C $KRITA_SRC_PATH log --format="$1: %D%n            %h -- %ai%n            %s" HEAD^..HEAD)
    IFS=$'\n'
    for nfo in $GITNFO
    do
        buildLog $nfo
    done

    git -C $KRITA_SRC_PATH log --format="%D%n%h -- %ai%n%s" HEAD^..HEAD > $GITNFO_FILE
    cat $GITNFO_FILE
}

function buildLogStart() {
    echo -n "" > $BUILDLOG_FILE
    echo -n "" > $OUTLOG_FILE
}

function buildLogGet() {
    local MODE=$1
    local TIME=$2
    local DEBUG=$3
    local VIEW=$4

    if [ "$DEBUG" == "Y" ]; then
        cat $DEBUGLOG_FILE > $GETLOG_FILE
    else
        if [ "$MODE" == 'short' ]; then
            cat $BUILDLOG_FILE > $GETLOG_FILE
        else
            cat $OUTLOG_FILE > $GETLOG_FILE
        fi

        if [ "$TIME" == 'Y' ]; then
            echo "" >> $GETLOG_FILE
            echo "--- Execution time" >> $GETLOG_FILE
            echo "" >> $GETLOG_FILE
        fi
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

function kritaInstallDeps() {
    # install dependencies
    # $1 = option verbose
    local REDIRECT=1
    local OPT_VERBOSE=$1

    if [ $OPT_VERBOSE -le 1 ]; then
        REDIRECT=/dev/null
    fi

    buildLog "kritaInstallDeps"

    buildLog "kritaInstallDeps KRITA_WS_PATH=$KRITA_WS_PATH"
    buildLog "kritaInstallDeps KRITA_SRC_PATH=$KRITA_SRC_PATH"

    if [[ -d $KRITA_WS_PATH/deps ]]; then
        rm -rfd $KRITA_WS_PATH/deps/* 1>&$REDIRECT || exit 1
    fi

    if [[ -d $KRITA_WS_PATH/deps-build ]]; then
        rm -rfd $KRITA_WS_PATH/deps-build/* 1>&$REDIRECT || exit 1
    fi

    if [[ -d $KRITA_WS_PATH/krita-deps-management ]]; then
        rm -rfd $KRITA_WS_PATH/krita-deps-management 1>&$REDIRECT || exit 1
    fi

    cd $KRITA_WS_PATH/deps

    buildLog "kritaInstallDeps: clone krita-deps-management"
    git clone https://invent.kde.org/dkazakov/krita-deps-management.git 1>&$REDIRECT || exit 1

    buildLog "kritaInstallDeps: clone ci-utilities"
    git clone https://invent.kde.org/dkazakov/ci-utilities.git krita-deps-management/ci-utilities 1>&$REDIRECT || exit 1

    buildLog "kritaInstallDeps: initialize Python virtual environment"
    python3 -m venv PythonEnv 1>&$REDIRECT || exit 1
    source $KRITA_WS_PATH/deps/PythonEnv/bin/activate 1>&$REDIRECT || exit 1
    python3 -m pip install -r krita-deps-management/requirements.txt 1>&$REDIRECT || exit 1

    buildLog "kritaInstallDeps: download & install dependencies"
    python3 krita-deps-management/tools/setup-env.py --full-krita-env -v PythonEnv 1>&$REDIRECT || exit 1

    buildLog "kritaInstallDeps: update deps/usr"
    mv $KRITA_WS_PATH/deps/_install/ $KRITA_WS_PATH/deps/usr/
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
    ARGS=$(getopt -o "s:d:r:" -l "scale:,debug:,reset:" -- "$@")
    eval set -- "$ARGS"

    EXEC=

    # cleanup any debug log file, if exists
    rm -f $DEBUGLOG_FILE

    while true; do
        case "$1" in
            -r | --reset)
                shift
                OPT_RESET=$1

                if [[ "$OPT_RESET" =~ c ]]; then
                    echo ".. Reset configuration"
                    rm -f ~/.config/krita*
                fi
                if [[ "$OPT_RESET" =~ r ]]; then
                    echo ".. Reset resources"
                    rm -rf ~/.local/share/krita
                    rm -f ~/.local/share/krita*
                fi
                ;;
            -s | --scale)
                shift
                export QT_SCALE_FACTOR=$1
                echo ".. Applying scale factor: $1"
                ;;
            -d | --debug)
                shift
                DEBUGGER=$1

                if [ $DEBUGGER == "gdb" ]; then
                    echo ".. Execute debug: gdb (debug-short.gdb)"
                    EXEC="gdb --command=~/.config/gdb/debug-short.gdb $KRITADIR_BIN"
                elif [ $DEBUGGER == "valgrind" ]; then
                    echo ".. Execute debug: valgrind"
                    EXEC="valgrind --log-file=$DEBUGLOG_FILE $KRITADIR_BIN"
                elif [ $DEBUGGER == "callgrind" ]; then
                    echo ".. Execute debug: callgrind"
                    EXEC="valgrind --tool=callgrind --callgrind-out-file=$DEBUGLOG_FILE $KRITADIR_BIN"
                fi
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done

    if [ "$EXEC" == "" ]; then
        EXEC="krita"
    fi
    $EXEC
}

function gdbExec() {
    # cleanup any debug log file, if exists
    rm -f $DEBUGLOG_FILE

    gdb --command=~/.config/gdb/debug-interactive.gdb $KRITADIR_BIN
}

function callgrindExec() {
    ARGS=$(getopt -l "start,stop" -- "$@")
    eval set -- "$ARGS"

    CMD_OPTION=

    while true; do
        case "$1" in
            --start)
                shift
                CMD_OPTION="--instr=on"
                ;;
            --stop)
                shift
                CMD_OPTION="--instr=off"
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done

    if [ "CMD_OPTION" == "" ]; then
        return
    fi

    callgrind_control $CMD_OPTION
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
    kritaInstallDeps)
        shift
        kritaInstallDeps $@
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
    gdbExec)
        shift
        gdbExec $@
        exit $?
        ;;
    callgrindExec)
        shift
        callgrindExec $@
        exit $?
        ;;
esac

exit 1


