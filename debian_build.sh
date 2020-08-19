#!/bin/bash
. ./tool/log.sh
. ./tool/tool.sh
. ./board.sh
. ./rootfs.sh

set -e
SCRIPT_NAME=${0##*/}

readonly ABSOLUTE_FILENAME=`readlink -e "$0"`
readonly ABSOLUTE_DIRECTORY=`dirname ${ABSOLUTE_FILENAME}`

# readonly CONFIG_FILE=${ABSOLUTE_DIRECTORY}"/config.ini"
readonly PACKAGES_PATH=${ABSOLUTE_DIRECTORY}"/.packeages"
readonly AUTO_PATH=${ABSOLUTE_DIRECTORY}"/.auto"
readonly DEB_PATH=${ABSOLUTE_DIRECTORY}"/.deb"
readonly TMP_ROOTFS_PATH=${ABSOLUTE_DIRECTORY}"/.tmp_rootfs"
readonly HOOKS_PATH=${ABSOLUTE_DIRECTORY}"/.hooks"
readonly TMP_COMPILE_PATH=${ABSOLUTE_DIRECTORY}"/.compile"
readonly LOG_PATH=${ABSOLUTE_DIRECTORY}"/logs"

readonly SCRIPT_START_DATE=$(date "+%Y%m%d");
readonly DEF_ROOTFS_TARBALL_NAME="rootfs_${SCRIPT_START_DATE}.tar.gz"  
# readonly DEF_ROOTFS_IMG_NAME="debian_${DEB_RELEASE}_avnet_${SCRIPT_START_DATE}.img"


readonly DEF_BUILDENV="${ABSOLUTE_DIRECTORY}"
# readonly G_ROOTFS_DIR="${DEF_BUILDENV}/rootfs"
# readonly G_TMP_DIR="${DEF_BUILDENV}/tmp"

PARAM_OUTPUT_DIR="${DEF_BUILDENV}/output"
PARAM_DEBUG=0
PARAM_CMD=""
CLEAN_CMD=""

BOARD_CONFIG_FILE=""
DEF_DEBIAN_MIRROR=""
DEB_RELEASE=""
DEF_ROOTFS_IMG_NAME=""

LINUX_SRC_OUTPUT=""
LINUX_IMG_OUTPUT=""
LINUX_GCC_OUTPUT=""
G_ROOTFS_IMAGE_DIR=""
G_ROOTFS_TARBALL_PATH=""
G_ROOTFS_IMAGE_PATH=""
G_ROOTFS_DIR=""
G_TMP_DIR=""

function usage()
{
    echo "Make Debian ${DEB_RELEASE} image and create a bootabled SD card"
    echo
    echo "Usage:"
    echo " ./${SCRIPT_NAME} options"
    echo
    echo "Options:"
    echo "  -h  -- print this help"
    echo "  -b <command>"
    echo "     Supported commands:"
    echo "       all         -- build whole debian image."
    echo "       rootfs      -- build or rebuild the Debian root filesystem and create rootfs.tar.gz."
    echo "       uboot       -- build uboot"
    echo "       linux       -- build linux"
    echo "  -f  -- custom select board config file"
    echo "  -c  <command>"
    echo "          Supported commands:"
    echo "            all         -- clean rootfs,uboot,linux output."
    echo "            rootfs      -- clean rootfs output"
    echo "            uboot       -- clean uboot output"
    echo "            linux       -- clean linux output"
    echo "  -o  -- custom select output directory (default: \"${PARAM_OUTPUT_DIR}\")"
    echo "Examples of use:"
    echo "  clean the workplace:            sudo ./debian_build.sh -c rootfs -f maaxboard.ini"
    echo "  make rootfs image:              sudo ./debian_build.sh -b rootfs -f maaxboard.ini"
    echo
}

# make firmware for wl bcm module
# $1 -- bcm git directory
# $2 -- rootfs output dir
function make_bcm_fw()
{
    log_info "Make and install bcm configs and firmware"

    #install -d ${2}/lib/firmware/bcm
    #install -d ${2}/lib/firmware/brcm
    #install -m 0644 ${1}/brcm/* ${2}/lib/firmware/brcm/
    #install -m 0644 ${1}/*.hcd ${2}/lib/firmware/bcm/
    #install -m 0644 ${1}/LICENSE ${2}/lib/firmware/bcm/
    #install -m 0644 ${1}/LICENSE ${2}/lib/firmware/brcm/
}

function make_prepare()
{
    LINUX_SRC_OUTPUT="${PARAM_OUTPUT_DIR}/02Linux/01LinuxSourceCode"
    LINUX_IMG_OUTPUT="${PARAM_OUTPUT_DIR}/02Linux/02LinuxShipmentImage"
    LINUX_GCC_OUTPUT="${PARAM_OUTPUT_DIR}/02Linux/03LinuxTools"
    G_ROOTFS_IMAGE_DIR="${PARAM_OUTPUT_DIR}/rootfs"
    G_ROOTFS_TARBALL_PATH="${G_ROOTFS_IMAGE_DIR}/${DEF_ROOTFS_TARBALL_NAME}"
    G_ROOTFS_IMAGE_PATH="${G_ROOTFS_IMAGE_DIR}/${DEF_ROOTFS_IMG_NAME}"
    G_ROOTFS_DIR="${G_ROOTFS_IMAGE_DIR}/filesystem"
    G_TMP_DIR="${G_ROOTFS_IMAGE_DIR}/tmp"
    # create rootfs dir
    mkdir -p ${G_ROOTFS_DIR}

    # create out dir
    mkdir -p ${PARAM_OUTPUT_DIR}

    # create tmp dir
    mkdir -p ${G_TMP_DIR}
    mkdir -p ${LINUX_SRC_OUTPUT}
    mkdir -p ${LINUX_IMG_OUTPUT}
    mkdir -p ${LINUX_GCC_OUTPUT}
    mkdir -p ${G_ROOTFS_IMAGE_DIR}
}


function cmd_make_clean()
{
    log_info "clean ${CLEAN_CMD}..."
    case $CLEAN_CMD in
        all )
            rm -rf ${PARAM_OUTPUT_DIR}
            ;;
        rootfs )
            rm -rf ${PARAM_OUTPUT_DIR}"/rootfs"
            ;;
        linux )
            rm -rf ${PARAM_OUTPUT_DIR}"/linux"
            ;;
        uboot )
            rm -rf ${PARAM_OUTPUT_DIR}"/uboot"
            ;;
        * )
            usage;
            exit 1;
            ;;
    esac
    exit 0;
}

function get_gcc(){
    cd ${ABSOLUTE_DIRECTORY}
    . ./gcc.sh
    prepare_gcc
}

function cmd_make_uboot(){
    cd ${ABSOLUTE_DIRECTORY}

    local status=$(is_function_exist gcc_all_build)
    if [[ $status != "0" ]];then
        get_gcc
    fi
    . ./uboot.sh
    build_uboot
}

function cmd_make_linux(){
    cd ${ABSOLUTE_DIRECTORY}
    local status=$(is_function_exist gcc_all_build)
    if [[ $status != "0" ]];then
        get_gcc
    fi
    . ./linux.sh
    build_linux
}

function cmd_make_all(){
    cd ${ABSOLUTE_DIRECTORY}
    . ./image.sh
    buidl_images
}

function start(){
    ## parse input arguments ##
    # readonly SHORTOPTS="c:o:d:h"
    # readonly LONGOPTS="cmd:,output:,dev:,help,debug"

    # ARGS=$(getopt -s bash --options ${SHORTOPTS} --longoptions ${LONGOPTS} --name ${SCRIPT_NAME} -- "$@" )
    # eval set -- "$ARGS"

    while getopts 'b:f:o:c:h' OPT; do
        case $OPT in
            b )
                PARAM_CMD="${OPTARG}";;
            f )
                BOARD_CONFIG_FILE="${OPTARG}";;
            o )
                PARAM_OUTPUT_DIR="${OPTARG}";;
            c )
                CLEAN_CMD="${OPTARG}";;
            h )
                usage
                exit -1;;
            ? )
                usage
                exit -1;;
        esac
    done
    if [[ -n $CLEAN_CMD ]];then
        if [[ -z ${BOARD_CONFIG_FILE} ]];then
            log_error "Invalid input command (-f): \"${BOARD_CONFIG_FILE}\"";
            usage;
            exit -1;
        fi
        local BORAD=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "BORAD");
        PARAM_OUTPUT_DIR=${PARAM_OUTPUT_DIR}"/"${BORAD}
        cmd_make_clean
    fi
    if [[ ${PARAM_CMD} != "rootfs" && ${PARAM_CMD} != "uboot" && ${PARAM_CMD} != "linux" && ${PARAM_CMD} != "all" ]];then
        log_error "Invalid input command (-b): \"${PARAM_CMD}\"";
        echo ""
        usage
        exit -1
    fi
    if [[ -z ${BOARD_CONFIG_FILE} ]];then
        log_error "Invalid input command (-f): \"${BOARD_CONFIG_FILE}\"";
        usage;
        exit -1;
    fi
    if [[ -s ${BOARD_CONFIG_FILE} ]];then
        BOARD_CONFIG_FILE=$(readlink -f ${BOARD_CONFIG_FILE})
    else
        log_error "${BOARD_CONFIG_FILE} not exist or empty!"
        exit -1;
    fi
    
    [ "${PARAM_DEBUG}" == 1 ] && {
        log_info "Debug mode enabled!"
        set -x
    };
    [ ${EUID} -ne 0 ] && {
        log_error "this command must be run as root (or sudo/su)"
        exit 1;
    };
    DEF_DEBIAN_MIRROR=$(load_config_file2 ${BOARD_CONFIG_FILE} "Debian" "DEBIAN_MIRROR");
    DEB_RELEASE=$(load_config_file2 ${BOARD_CONFIG_FILE} "Debian" "DEBIAN_RELEASE");
    local BORAD=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "BORAD");

    DEF_ROOTFS_IMG_NAME="debian_${DEB_RELEASE}_avnet_${SCRIPT_START_DATE}.img"

    PARAM_OUTPUT_DIR=${PARAM_OUTPUT_DIR}"/"${BORAD}
    # log_info "Command: \"$PARAM_CMD\" start...";
    make_prepare

    case $PARAM_CMD in
        all )
            cmd_make_all
            ;;
        rootfs )
            cmd_make_rootfs
            ;;
        linux )
            cmd_make_linux
            ;;
        uboot )
            cmd_make_uboot
            ;;
        * )
            usage;
            exit 1;
            ;;
    esac
}

start $@;