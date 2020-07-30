#!/bin/bash

function start_desktop(){
    if $1
    then
        log_info "install decktop";
    else
        log_error "uninstall decktop";
    fi;
}

function desktop_backgroud(){
    local ROOTFS_BASE=$1
    local conf_weston=$(loadConf "Desktop" "WESTON");
    if [[ ! -z $conf_weston && $conf_weston == "true" ]]
    then
        mkdir -p ${ROOTFS_BASE}/usr/share/images/desktop-base/
        install -m 0644 ${G_WORK_PATH}/desktop.jpg \
            ${ROOTFS_BASE}/usr/share/images/desktop-base/default
    fi
}

function weston_service(){
    local ROOTFS_BASE=$1
    # install weston service
    install -d ${ROOTFS_BASE}/etc/xdg/weston
    install -m 0644 ${G_WORK_PATH}/${BOARD}/weston.ini \
        ${ROOTFS_BASE}/etc/xdg/weston
    install -m 0755 ${G_WORK_PATH}/${BOARD}/weston.config \
        ${ROOTFS_BASE}/etc/default/weston
    install -m 0755 ${G_WORK_PATH}/weston-start \
        ${ROOTFS_BASE}/usr/bin/weston-start
    install -m 0755 ${G_WORK_PATH}/weston.profile \
        ${ROOTFS_BASE}/etc/profile.d/weston.sh
    install -m 0644 ${G_WORK_PATH}/weston.service \
        ${ROOTFS_BASE}/lib/systemd/system
    ln -s ${ROOTFS_BASE}/lib/systemd/system/weston.service \
        ${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/weston.service
}

function install_weston(){
    ROOTFS_BASE=$1
    local conf_weston=$(loadConf "Desktop" "WESTON");
    if [[ ! -z $conf_weston && $conf_weston == "true" ]]
    then
        weston_service $ROOTFS_BASE
        
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/weston-init-1.0-r0.tar.gz  -C  ${ROOTFS_BASE}
    	tar --no-same-owner -xzf ${G_WORK_PATH}/packages/weston-5.0.0.imx.tar.gz  -C  ${ROOTFS_BASE}
    fi;
}