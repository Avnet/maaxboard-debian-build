#!/bin/bash

function install_Qt(){
    local ROOTFS_BASE=$1
    local conf_qt=$(loadConf "Qt" "NEED_INSTALL");
    if $conf_qt
    then
        tar --no-same-owner -xzf ${G_WORK_PATH}/packages/qtbase.tar.gz  -C  ${ROOTFS_BASE}

        local conf_weston=$(loadConf "Desktop" "WESTON");
        if $conf_weston
        then
            tar --no-same-owner -xzf ${G_WORK_PATH}/packages/qtwayland.tar.gz  -C  ${ROOTFS_BASE}
        fi

        rm -rf ${ROOTFS_BASE}/usr/lib/qtbase/
        rm -rf ${ROOTFS_BASE}/usr/share/doc/qt5/
        rm -rf ${ROOTFS_BASE}/usr/share/qt5/

        echo "export QT_QPA_FONTDIR=/usr/share/fonts/truetype/dejavu" >> ${ROOTFS_BASE}/etc/profile.d/qt5.sh
        echo "export QT_FONT_SIZE_0=2" >> ${ROOTFS_BASE}/etc/profile.d/qt5.sh
    fi;
}