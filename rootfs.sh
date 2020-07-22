#!/bin/bash

function download_local_deb(){
    src=$1
    target=$2

    cp -r $src $target
}

function install_bluetooth(){
    local conf_bluetooth=$(loadConf "Third" "BLUETOOTH");
    if $conf_bluetooth
        protected_install bluetooth
        protected_install bluez-obexd
        protected_install bluez-tools
        protected_install blueman
    then
    fi
}

function install_gstreamer(){
    local LOCAL_APT_PATH=$1
    local conf_gst=$(loadConf "Hardware" "Gstreamer");
    if $conf_gst
    then
        # gstpluginsbad
        cp -r ${G_WORK_PATH}/deb/gstpluginsbad/${GST_MM_VERSION}/* $LOCAL_APT_PATH

        # gstpluginsbase
        cp -r ${G_WORK_PATH}/deb/gstpluginsbase/${GST_MM_VERSION}/* $LOCAL_APT_PATH

        # gstpluginsgood
        cp -r ${G_WORK_PATH}/deb/gstpluginsgood/${GST_MM_VERSION}/* $LOCAL_APT_PATH

        # gstreamer
        cp -r ${G_WORK_PATH}/deb/gstreamer/${GST_MM_VERSION}/* $LOCAL_APT_PATH

        # imxgstplugin
        cp -r ${G_WORK_PATH}/deb/imxgstplugin/${GST_MM_VERSION}/* $LOCAL_APT_PATH

        protected_install gstreamer1.0-alsa
        protected_install gstreamer1.0-plugins-bad
        protected_install gstreamer1.0-plugins-base
        protected_install gstreamer1.0-plugins-base-apps
        protected_install gstreamer1.0-plugins-ugly
        protected_install gstreamer1.0-plugins-good
        protected_install gstreamer1.0-tools
        protected_install ${IMXGSTPLG}
    fi;
}

function install_ssh(){
    local conf_ssh=$(loadConf "Third" "SSH");
    if $conf_ssh
    then
        protected_install openssh-server
        protected_install openssh-client
        # fix config for sshd (permit root login)
        sed -i -e 's/#PermitRootLogin.*/PermitRootLogin\tyes/g' /etc/ssh/sshd_config
    fi;
}

function create_users(){
    # create users and set password
    useradd -m -G audio -s /bin/bash avnet
    usermod -a -G video avnet
    echo "avnet:avnet" | chpasswd
    echo "root:avnet" | chpasswd
}

function install_third_stage(){
    local LOCAL_APT_PATH=$1
    debconf-set-selections /debconf.set
    rm -f /debconf.set

    apt-get update && apt-get upgrade -y
    # local-apt-repository support
    protected_install local-apt-repository
    # update packages and install base
    apt-get update || apt-get upgrade

    protected_install locales
    protected_install ntp

    install_ssh;

    protected_install nfs-common
    protected_install parted
    protected_install exfat-fuse
    protected_install vim
    protected_install cpufrequtils

    #git
    local conf_git=$(loadConf "Third" "GIT");
    if $conf_git
    then
        protected_install git
    fi;

    #dosfstools
    local conf_dosfstools=$(loadConf "Third" "DOSFSTOOLS");
    if $conf_dosfstools
    then
        protected_install dosfstools
    fi;

    # net-tools (ifconfig, etc.)
    protected_install net-tools
    protected_install network-manager

    cp -r ${G_WORK_PATH}/deb/imx-firmware-${IMX_FIRMWARE_VERSION}/* $LOCAL_APT_PATH
    protected_install imx-firmware-sdma
    local conf_vpu=$(loadConf "Hardware" "VPU");
    if $conf_vpu
    then
        protected_install imx-firmware-vpu
    fi;
    protected_install imx-firmware-epdc

    protected_install alsa-utils
    # gstreamer
    install_gstreamer $LOCAL_APT_PATH

    local conf_i2c=$(loadConf "Third" "I2C");
    if $conf_i2c
    then
        protected_install i2c-tools
    fi;
    # usb tools
    protected_install usbutils
    protected_install picocom
    # net tools
    protected_install iperf

    protected_install rng-tools
    # mtd
    protected_install mtd-utils

    install_bluetooth

    protected_install gconf2
    # wifi support packages
    protected_install hostapd
    protected_install udhcpd

    # disable the hostapd service by default
    systemctl disable hostapd.service
    # can support
    protected_install can-utils
    # pmount
    protected_install pmount
    # pm-utils
    protected_install pm-utils

    apt-get -y autoremove

    #update iptables alternatives to legacy
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

    create_users;
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

    echo "${BORAD}" > etc/hostname

    echo "auto lo" > etc/network/interfaces
    echo "iface lo inet loopback" >> etc/network/interfaces

    echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" > debconf.set
    echo "locales locales/default_environment_locale select en_US.UTF-8" >> debconf.set
    echo "console-common	console-data/keymap/policy	select	Select keymap from full list" >> debconf.set
    echo "keyboard-configuration keyboard-configuration/variant select 'English (US)'" >> debconf.set
    echo "openssh-server openssh-server/permit-root-login select true" >> debconf.set
}

function prepare_policy(){
    local ROOTFS_BASE= $1
    # apt-get install without starting
    cat > ${ROOTFS_BASE}/usr/sbin/policy-rc.d << EOF
    #!/bin/sh
    exit 101
    EOF
    chmod +x ${ROOTFS_BASE}/usr/sbin/policy-rc.d
}

function prepare_qemu(){
    local ROOTFS_BASE= $1
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

function cleanGL(){
    local ROOTFS_BASE=$1
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/gbm_viv.so
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/libEGL.so.1*
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/libevdev.so.2*
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/libglapi.so.0*
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/libGL.so.1*
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/vivante/
    rm -rf ${ROOTFS_BASE}/usr/lib/aarch64-linux-gnu/dri/swrast_dri.so
}

function install_tars(){
    local ROOTFS_BASE=$1
    log_info "copy packages"
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/libdrm.2.4.91.imx.tar.gz  -C  ${ROOTFS_BASE}
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/libinput.1.9.4-r0.tar.gz  -C  ${ROOTFS_BASE}
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/libevdev-1.5.8-r0.tar.gz  -C  ${ROOTFS_BASE}
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/mtdev-1.1.5-r0.tar.gz  -C  ${ROOTFS_BASE}
    # add kernel module
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/m.kernel.tar.gz  -C  ${G_ROOTFS_DIR}

    local conf_chrome=$(loadConf "Third" "CHROME");
    if $conf_chrome
    then
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/chrome.v71.tar.gz  -C  ${ROOTFS_BASE}
    fi;

    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/devil.tar.gz  -C  ${ROOTFS_BASE}
    tar --no-same-owner -xzf ${G_WORK_PATH}/packages/mesa.tar.gz  -C  ${ROOTFS_BASE}
    local conf_gpu=$(loadConf "Hardware" "GPU");
    if $conf_gpu
    then
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/imx-gpu-viv.tar.gz  -C  ${ROOTFS_BASE}
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/libgpuperfcnt.tar.gz  -C  ${ROOTFS_BASE}
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/gputop.tar.gz  -C  ${ROOTFS_BASE}
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/imx-gpu-sdk.tar.gz  -C  ${ROOTFS_BASE}
    fi;
    local conf_vpu=$(loadConf "Hardware" "VPU");
    if $conf_vpu
    then
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/imx-vpuwrap.tar.gz  -C  ${ROOTFS_BASE}
    fi;

    install_Qt $ROOTFS_BASE
}

function cleanup(){
	ROOTFS_BASE=$1
    log_info "rootfs: clean"
    apt-get clean
    umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true
    QEMU_PROC_ID=$(ps axf | grep dbus-daemon | grep qemu-aarch64-static | awk '{print $1}')
    if [ -n "$QEMU_PROC_ID" ];then
        kill -9 $QEMU_PROC_ID
    fi
    rm -f ${ROOTFS_BASE}/usr/bin/qemu-aarch64-static
}

function install_system(){
    ROOTFS_BASE=$1
    log_info "rootfs: install system configuration"
    #install securetty
    install -m 0644 ${G_WORK_PATH}/securetty \
        ${ROOTFS_BASE}/etc/securetty

    install_weston $ROOTFS_BASE

    # remove pm-utils default scripts and install wifi / bt pm-utils script
    rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/sleep.d/
    rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/module.d/
    rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/power.d/

    log_info "binaries rootfs patching......"
    ## binaries rootfs patching ##
    install -m 0644 ${G_WORK_PATH}/issue ${ROOTFS_BASE}/etc/
    install -m 0644 ${G_WORK_PATH}/issue.net ${ROOTFS_BASE}/etc/
    install -m 0755 ${G_WORK_PATH}/rc.local ${ROOTFS_BASE}/etc/
    install -d ${ROOTFS_BASE}/boot/

    desktop_backgroud $ROOTFS_BASE
    # Revert regular booting
    rm -f ${ROOTFS_BASE}/usr/sbin/policy-rc.d

    # copy custom files
    cp ${G_WORK_PATH}/fw_env.config ${ROOTFS_BASE}/etc
    cp ${G_WORK_PATH}/10-imx.rules ${ROOTFS_BASE}/etc/udev/rules.d
    cp ${G_WORK_PATH}/mount.blacklist ${ROOTFS_BASE}/etc/udev/rules.d
    cp ${G_WORK_PATH}/automount.rules ${ROOTFS_BASE}/etc/udev/rules.d
    mkdir -p ${ROOTFS_BASE}/etc/udev/scripts/
    install -m 0755 ${G_WORK_PATH}/mount.sh \
        ${ROOTFS_BASE}/etc/udev/scripts/mount.sh

    if [ "${BOARD}" == "maaxboard" ]; then
        cp ${G_WORK_PATH}/${BOARD}/*.rules ${ROOTFS_BASE}/etc/udev/rules.d
    fi
    cleanGL $ROOTFS_BASE
    install_tars $ROOTFS_BASE
    log_info "build finished..........."
    cleanup $ROOTFS_BASE
    log_info "make debian rootfs done....."
}

function make_debian_rootfs(){
    local ROOTFS_BASE=$1;
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

    local LOCAL_APT_PATH=${ROOTFS_BASE}/srv/local-apt-repository
    mkdir -p $LOCAL_APT_PATH

    prepare_system_config
    prepare_policy $ROOTFS_BASE

    install_third_stage $LOCAL_APT_PATH

    install_system $ROOTFS_BASE

}