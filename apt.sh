#!/bin/bash
. /tmp/tool/log.sh
. /tmp/tool/tool.sh
. /tmp/board.sh

readonly LOG_PATH="/tmp/logs"
readonly ABSOLUTE_FILENAME=`readlink -e "$0"`
readonly ABSOLUTE_DIRECTORY=`dirname ${ABSOLUTE_FILENAME}`
function create_users(){
    # create users and set password
    useradd -m -G audio -s /bin/bash avnet
    usermod -a -G video avnet
    echo "avnet:avnet" | chpasswd
    echo "root:avnet" | chpasswd
}

function load_hooks(){
    [[ -s "/tmp/pre_apt_hook" ]] && . /tmp/pre_apt_hook
    [[ -s "/tmp/post_apt_hook" ]] && . /tmp/post_apt_hook
}

function install_apts(){
    load_hooks;
    local ROOTFS_BASE="/tmp"

    pre_call_function ${ROOTFS_BASE} "Apt" "all"

    apt-get update && apt-get upgrade -y
    # local-apt-repository support
    protected_install local-apt-repository
    # update packages and install base
    apt-get update
    # apt install board.ini->Apt 
    install_apt $ROOTFS_BASE;

    post_call_function ${ROOTFS_BASE} "Apt" "all"
    apt-get -y autoremove
    #update iptables alternatives to legacy
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

    create_users;
}

install_apts;