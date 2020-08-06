#!/bin/bash

function create_users(){
    # create users and set password
    useradd -m -G audio -s /bin/bash avnet
    usermod -a -G video avnet
    echo "avnet:avnet" | chpasswd
    echo "root:avnet" | chpasswd
}

function install_third_stage(){
    local LOCAL_APT_PATH=$1
    cp ${ABSOLUTE_DIRECTORY}/apt.sh ${ROOTFS_BASE}/tmp/apt.sh
    mkdir -p ${ROOTFS_BASE}/tmp/tool

    cp ${ABSOLUTE_DIRECTORY}/tool/log.sh ${ROOTFS_BASE}/tmp/tool/log.sh
    cp ${ABSOLUTE_DIRECTORY}/tool/tool.sh ${ROOTFS_BASE}/tmp/tool/tool.sh
    cp ${ABSOLUTE_DIRECTORY}/board.sh ${ROOTFS_BASE}/tmp/board.sh
    cp ${ABSOLUTE_DIRECTORY}/*.ini  ${ROOTFS_BASE}/tmp/

    [[ -s ${HOOKS_PATH}"/pre_apt_hook" ]] && cp ${HOOKS_PATH}"/pre_apt_hook" ${ROOTFS_BASE}/tmp/pre_apt_hook
    [[ -s ${HOOKS_PATH}"/post_apt_hook" ]] && cp ${HOOKS_PATH}"/post_apt_hook" ${ROOTFS_BASE}/tmp/post_apt_hook
    chmod +x ${ROOTFS_BASE}/tmp/apt.sh

    # pre_call_function ${ROOTFS_BASE} "Apt" "all"
    chroot ${ROOTFS_BASE} /tmp/apt.sh
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

    local BOARD_CONF=$(get_board_config_name)
    local BORAD=$(load_config_file2 ${BOARD_CONF} "Base" "BORAD");
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
    rm -rf ${ROOTFS_BASE}/*

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
    install_third_stage $LOCAL_APT_PATH

    install_system $ROOTFS_BASE
}