#!/bin/bash

function create_users(){
    # create users and set password
    useradd -m -G audio -s /bin/bash avnet
    usermod -a -G video avnet
    echo "avnet:avnet" | chpasswd
    echo "root:avnet" | chpasswd
}

function cp_board_ini(){
    local ROOTFS_BASE=$1
    local m_file=$2
    cp $m_file $ROOTFS_BASE"/tmp/"

    local includes=$(load_section $m_file "Include")
    
    if [[ -n $includes ]];then
        local tmp_path=$(get_file_path ${m_file})
        IFS_old=$IFS 
        IFS=$'\n'
        for sect in ${includes[@]}
        do

            # sub_file=$(parse_config_value $sect)
            sub_file=$(parse_config_value $sect)
            tmp_sub_file=$sub_file
            if [[ "${sub_file}" == "./"* ]];then
                sub_file=${tmp_path}"/"${sub_file:2}
            fi
            # load_section2 $sub_file $m_section
            sed -i "s!${tmp_sub_file}!/tmp/${tmp_sub_file##*/}!g" $ROOTFS_BASE"/tmp/"${m_file##*/}
            cp_board_ini $ROOTFS_BASE $sub_file 
        done
        IFS=$IFS_old
    fi
}

function install_third_stage(){
    local ROOTFS_BASE=$1
    cp ${ABSOLUTE_DIRECTORY}/apt.sh ${ROOTFS_BASE}/tmp/apt.sh
    mkdir -p ${ROOTFS_BASE}/tmp/tool


    cp ${ABSOLUTE_DIRECTORY}/tool/log.sh ${ROOTFS_BASE}/tmp/tool/log.sh
    cp ${ABSOLUTE_DIRECTORY}/tool/tool.sh ${ROOTFS_BASE}/tmp/tool/tool.sh
    cp ${ABSOLUTE_DIRECTORY}/board.sh ${ROOTFS_BASE}/tmp/board.sh

    # cp ${BOARD_CONFIG_FILE}  ${ROOTFS_BASE}/tmp/
    cp_board_ini $ROOTFS_BASE $BOARD_CONFIG_FILE

    sed -i "s!BOARD_CONFIG_FILE=\"\"!BOARD_CONFIG_FILE=/tmp/${BOARD_CONFIG_FILE##*/}!g" ${ROOTFS_BASE}/tmp/apt.sh

    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})
    local pre_hook=$(load_config_file2 ${BOARD_CONFIG_FILE} "Hooks" "pre_apt_hook");
    local post_hook=$(load_config_file2 ${BOARD_CONFIG_FILE} "Hooks" "post_apt_hook");
    if [[ ${pre_hook} == "./"* ]];then
        pre_hook=${tmp_path}"/"${pre_hook:2}
    fi
    if [[ ${post_hook} == "./"* ]];then
        post_hook=${tmp_path}"/"${post_hook:2}
    fi

    [[ -s ${pre_hook} ]] && cp ${pre_hook} ${ROOTFS_BASE}/tmp/pre_apt_hook
    [[ -s ${post_hook} ]] && cp ${post_hook} ${ROOTFS_BASE}/tmp/post_apt_hook
    chmod +x ${ROOTFS_BASE}/tmp/apt.sh

    # pre_call_function ${ROOTFS_BASE} "Apt" "all"
    chroot ${ROOTFS_BASE} /tmp/apt.sh ${BOARD_CONFIG_FILE}
    # post_call_function ${ROOTFS_BASE} "Apt" "all"
}

function prepare_system_config(){
    # add mirror to source list
    echo "deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free " > etc/apt/sources.list
    echo "deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free" >> etc/apt/sources.list
    echo "deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free" >> etc/apt/sources.list
    echo "deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free" >> etc/apt/sources.list

    # raise backports priority
    echo "Package: *" > etc/apt/preferences.d/backports
    echo "Pin: release n=${DEB_RELEASE}-backports">> etc/apt/preferences.d/backports
    echo "Pin-Priority: 500">> etc/apt/preferences.d/backports

    # maximize local repo priority
    echo "Package: *" > etc/apt/preferences.d/local
    echo "Pin: origin """ >> etc/apt/preferences.d/local
    echo "Pin-Priority: 1000 ">> etc/apt/preferences.d/local
    
    echo "/dev/mmcblk0p1  /boot           vfat    defaults        0       0" > etc/fstab

    local BORAD=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "BORAD");
    echo "${BORAD}" > etc/hostname

    echo "auto lo" > etc/network/interfaces
    echo "iface lo inet loopback" >> etc/network/interfaces
}

function prepare_policy(){
    local ROOTFS_BASE=$1
    # apt-get install without starting
    # cat > ${ROOTFS_BASE}/usr/sbin/policy-rc.d << EOF
    # #!/bin/sh
    # exit 101
    # EOF
    echo "#!/bin/sh" > ${ROOTFS_BASE}/usr/sbin/policy-rc.d
    echo "exit 101" >> ${ROOTFS_BASE}/usr/sbin/policy-rc.d
    chmod +x ${ROOTFS_BASE}/usr/sbin/policy-rc.d
}

function prepare_qemu(){
    local ROOTFS_BASE=$1;
    log_info "rootfs: debootstrap";
    debootstrap --verbose --no-check-gpg --foreign --arch arm64 ${DEB_RELEASE} \
        ${ROOTFS_BASE}/ ${DEF_DEBIAN_MIRROR}

    log_info "rootfs: debootstrap in rootfs (second-stage)";
    cp /usr/bin/qemu-aarch64-static ${ROOTFS_BASE}/usr/bin/
    mount -o bind /proc ${ROOTFS_BASE}/proc
    mount -o bind /dev ${ROOTFS_BASE}/dev
    mount -o bind /dev/pts ${ROOTFS_BASE}/dev/pts
    mount -o bind /sys ${ROOTFS_BASE}/sys
    chroot $ROOTFS_BASE /debootstrap/debootstrap --second-stage

    # delete unused folder
    chroot $ROOTFS_BASE rm -rf ${ROOTFS_BASE}/debootstrap
}

function install_tars(){
    local ROOTFS_BASE=$1
 
    install_packages ${ROOTFS_BASE}
    install_auto_packages ${ROOTFS_BASE}
}

function cleanup(){
    local ROOTFS_BASE=$1
    local cleanup_file=${ROOTFS_BASE}"/tmp/cleanup"
    echo "#!/bin/bash" > ${cleanup_file}
    echo "apt-get clean" >> ${cleanup_file}
    echo "rm -f /tmp/cleanup" >> ${cleanup_file}
    chmod +x ${cleanup_file}
    chroot ${ROOTFS_BASE} /tmp/cleanup

    umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true
    QEMU_PROC_ID=$(ps axf | grep dbus-daemon | grep qemu-aarch64-static | awk '{print $1}')
    if [ -n "$QEMU_PROC_ID" ];then
        kill -9 $QEMU_PROC_ID
    fi
    rm -f ${ROOTFS_BASE}/usr/bin/qemu-aarch64-static
}

function install_system(){
    local ROOTFS_BASE=$1
    log_info "rootfs: install system configuration"
    #install securetty
    # install_weston $ROOTFS_BASE
    install_rootfs $ROOTFS_BASE

    # copy custom files
    # if [ "${BOARD}" == "maaxboard" ]; then
    #     cp ${G_WORK_PATH}/${BOARD}/*.rules ${ROOTFS_BASE}/etc/udev/rules.d
    # fi

    install_tars $ROOTFS_BASE
    log_info "build finished..........."
    cleanup $ROOTFS_BASE
    log_info "make debian rootfs done....."
}

function make_debian_rootfs(){
    local ROOTFS_BASE=$1;

    log_info "Download packages..."
    mkdir -p $DEB_PATH
    download_board_packages $DEB_PATH

    log_info "Make Debian (${DEB_RELEASE}) rootfs start...";

    # umount previus mounts (if fail)
    umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true

    # clear rootfs dir
    # rm -rf ${ROOTFS_BASE}/*

    prepare_qemu $ROOTFS_BASE

    log_info "rootfs: generate default configs";
    mkdir -p ${ROOTFS_BASE}/etc/sudoers.d/
    echo "avnet ALL=(root) /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/vi, /sbin/reboot" > ${ROOTFS_BASE}/etc/sudoers.d/avnet
    chmod 0440 ${ROOTFS_BASE}/etc/sudoers.d/avnet

    prepare_system_config
    prepare_policy $ROOTFS_BASE

    load_hooks;

    local LOCAL_APT_PATH=${ROOTFS_BASE}/srv/local-apt-repository
    mkdir -p $LOCAL_APT_PATH
    cp $DEB_PATH/* $LOCAL_APT_PATH
    install_third_stage $ROOTFS_BASE

    install_system $ROOTFS_BASE
}

function make_tarball()
{
    cd $1

    chown root:root .
    log_info "make tarball from folder ${1}"
    log_info "Remove old tarball $2"
    rm -f $2

    log_info "Create $2"

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

function make_rootfs_images()
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
    local imagesize=$(du -sm ${1} 2>/dev/null | awk '{print $1}')
    imagesize=$((`echo $imagesize | sed 's/M//'`))
    log_info "imagesize=${imagesize}"
    local extend_size=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "images_extend_size");
    imagesize=$(($imagesize+$extend_size))
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
    echo "=============== Build summary ==============="
    echo "Building Debian ${DEB_RELEASE} for ${BOARD_CONFIG_FILE}"

    echo "============================================="

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
    make_rootfs_images ${G_ROOTFS_DIR} ${G_ROOTFS_IMAGE_PATH}
}