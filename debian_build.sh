#!/bin/bash
. ./tool/log.sh
. ./tool/tool.sh
. ./board.sh
. ./rootfs.sh

SCRIPT_NAME=${0##*/}

readonly ABSOLUTE_FILENAME=`readlink -e "$0"`
readonly ABSOLUTE_DIRECTORY=`dirname ${ABSOLUTE_FILENAME}`

readonly SCRIPT_START_DATE=$(date "+%Y%m%d");
readonly DEF_ROOTFS_TARBALL_NAME="rootfs_${SCRIPT_START_DATE}.tar.gz"  
readonly DEF_ROOTFS_IMG_NAME="debian_buster_avnet_${SCRIPT_START_DATE}.img"

readonly DEF_DEBIAN_MIRROR=$(loadConf "Debian" "DEBIAN_MIRROR");
readonly DEB_RELEASE=$(loadConf "Debian" "DEBIAN_RELEASE");

readonly DEF_BUILDENV="${ABSOLUTE_DIRECTORY}"
readonly DEF_SRC_DIR="${DEF_BUILDENV}/src"
readonly G_WORK_PATH="${DEF_BUILDENV}/avnet"
readonly G_ROOTFS_DIR="${DEF_BUILDENV}/rootfs"
readonly G_TMP_DIR="${DEF_BUILDENV}/tmp"

PARAM_OUTPUT_DIR="${DEF_BUILDENV}/output"
PARAM_DEBUG=0
PARAM_CMD=""

readonly G_ROOTFS_TARBALL_PATH="${PARAM_OUTPUT_DIR}/${DEF_ROOTFS_TARBALL_NAME}"
readonly G_ROOTFS_IMAGE_PATH="${PARAM_OUTPUT_DIR}/${DEF_ROOTFS_IMG_NAME}"

function usage()
{
    echo "Make Debian ${DEB_RELEASE} image and create a bootabled SD card"
    echo
    echo "Usage:"
    echo " BOARD=<maaxboard/maaxboard_mini> ./${SCRIPT_NAME} options"
    echo
    echo "Options:"
    echo "  -h|--help   -- print this help"
    echo "  -c|--cmd <command>"
    echo "     Supported commands:"
    echo "       rootfs      -- build or rebuild the Debian root filesystem and create rootfs.tar.gz"
    echo "                       (including: make & install Debian packages, firmware and kernel modules & headers)"
    echo "       rtar        -- generate or regenerate rootfs.tar.gz image from the rootfs folder"
    echo "       clean       -- clean all build artifacts (without deleting sources code or resulted images)"
    echo "  -o|--output -- custom select output directory (default: \"${PARAM_OUTPUT_DIR}\")"
    echo "  --debug     -- enable debug mode for this script"
    echo "Examples of use:"
    echo "  clean the workplace:            sudo BOARD=maaxboard/maaxboard_mini ./debian_build.sh -c clean"
    echo "  make rootfs image:              sudo BOARD=maaxboard/maaxboard_mini ./debian_build.sh -c rootfs"
    echo
}

function checkBorad(){
    echo $BOARD
    if [ ! -e ${G_WORK_PATH}/${BOARD}/${BOARD}.sh ]; then
        log_error "Illegal Board: ${BOARD}";
        usage;
        exit 1
    fi
}

function checkPermission(){
    [ ${EUID} -ne 0 ] && {
        log_error "this command must be run as root (or sudo/su)"
        exit 1;
    };
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
    # create rootfs dir
    mkdir -p ${G_ROOTFS_DIR}

    # create out dir
    mkdir -p ${PARAM_OUTPUT_DIR}

    # create tmp dir
    mkdir -p ${G_TMP_DIR}
}

function make_tarball()
{
    cd $1

    chown root:root .
    pr_info "make tarball from folder ${1}"
    pr_info "Remove old tarball $2"
    rm -f $2

    pr_info "Create $2"

    RETVAL=0
    tar czf $2 . || {
        RETVAL=1
        rm -f $2
    };

    cd -
    return $RETVAL
}

# make tarball from footfs
# $1 -- packet folder
# $2 -- output tarball file (full name)
function check_dependencies () {
    unset deb_pkgs
    dpkg -l | grep dosfstools >/dev/null || deb_pkgs="${deb_pkgs}dosfstools "

    if [ "${deb_pkgs}" ] ; then
        log_info "Installing: ${deb_pkgs}"
        sudo apt-get update
        sudo apt-get -y install ${deb_pkgs}
    fi
}

function make_images()
{
    #Find the WORKDIR, then we can find .project
    cd $1

    chown root:root .
    log_info "make image from folder ${1}"
    log_info "add ext4  image into $2"
    #rm -f $2

    log_info "add $2"

    #Main functions
    check_dependencies
    log_info "Begin generate ext4 img ..."
    imagesize=$(du -sm ${1} 2>/dev/null | awk '{print $1}')
    imagesize=$((`echo $imagesize | sed 's/M//'`))
    log_info "imagesize=${imagesize}"
    imagesize=$(($imagesize+1536))
    log_info "imagesize all =${imagesize}"

    dd if=/dev/zero of="$2" bs=1M count=0 seek=$imagesize
    EXT4_LOOP="$(losetup --sizelimit ${imagesize}M -f --show $2)"
    mkfs.ext4 "$EXT4_LOOP"
    MOUNTDIR="$G_TMP_DIR"
    mkdir -p "$MOUNTDIR"
    mount "$EXT4_LOOP" "$MOUNTDIR"
    rsync -a "${1}/" "$MOUNTDIR/"
    umount "$MOUNTDIR"
    losetup -d "$EXT4_LOOP"
    log_info "mkimage done.........."
    if which bmaptool; then
        bmaptool create -o "$G_TMP_DIR/debian-buster.img.bmap" "$2"
    fi
}

function cmd_make_rootfs(){
    # make Debian rootfs
    cd ${G_ROOTFS_DIR}
    make_debian_rootfs ${G_ROOTFS_DIR}
    cd -

    # # make bcm firmwares
    # make_bcm_fw ${G_BCM_FW_SRC_DIR} ${G_ROOTFS_DIR}

    log_info "start to build rootfs"
    # # pack rootfs
    make_tarball ${G_ROOTFS_DIR} ${G_ROOTFS_TARBALL_PATH}

    # #make images for rootfs
    make_images ${G_ROOTFS_DIR} ${G_ROOTFS_IMAGE_PATH}
}

function start(){
    while [[ $# -ge 1 ]]; do
        case $1 in
            -c|--cmd )
                shift
                PARAM_CMD="$1";
                ;;
            -o|--output ) # select output dir
                shift
                PARAM_OUTPUT_DIR="$1";
                ;;
            --debug ) # enable debug
                PARAM_DEBUG=1;
                ;;
            -h|--help ) # get help
                usage
                exit 0;
                ;;
            * )
                shift
                ;;
        esac
        shift
    done
    
    if [[ $PARAM_CMD == "rootfs" || $PARAM_CMD == "rtar" || $PARAM_CMD == "clean" ]]
    then
        :
    else
        log_error "Invalid input command (-c): \"${PARAM_CMD}\"";
        exit 0;
    fi

    [ "${PARAM_DEBUG}" == 1 ] && {
        log_info "Debug mode enabled!"
        set -x
    };
    checkPermission;
    # checkBorad;
    echo "=============== Build summary ==============="
    echo "Building Debian ${DEB_RELEASE} for ${BOARD}"

    echo "Kernel config:      ${G_LINUX_KERNEL_DEF_CONFIG}"
    echo "Default kernel dtb: ${DEFAULT_BOOT_DTB}"
    echo "kernel dtbs:        ${G_LINUX_DTB}"
    echo "============================================="
    echo

    log_info "Command: \"$PARAM_CMD\" start...";
    make_prepare

    case $PARAM_CMD in
        rootfs )
            cmd_make_rootfs
            ;;
        rtar )
            cmd_make_rfs_tar
            ;;
        clean )
            cmd_make_clean
            ;;
        * )
            log_error "Invalid input command: \"${PARAM_CMD}\"";
            ;;
    esac
    # v1=$(loadConf "Debian" "DEBIAN_RELEASE");
    # v2=$(loadConf "Qt" "NEED_INSTALL");
    # v3=$(loadConf "Desktop" "NEED_INSTALL");
    # start_desktop $v3
    # start_qt $v2
}

start $@;