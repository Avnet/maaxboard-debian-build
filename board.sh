#!/bin/bash

CACHE_PATH=".cache"
DOWNLOAD_ERROR=".cache/error"
DOWNLOAD_OK=".cache/ok"

AUTO_PATH=".auto"
AUTO_DOWNLOAD_ERROR=".auto/error"
AUTO_DOWNLOAD_OK=".auto/ok"

function open_pip_async(){
    local THREAD_NUM=$(loadConf "Base" "download_num");
    #create pip
    [ -e /tmp/fd1 ] || mkfifo /tmp/fd1
    # fd 3 relate to pip
    exec 3<>/tmp/fd1
    # After related,we just need fd 
    rm -rf /tmp/fd1 

    for ((i=1;i<=${THREAD_NUM};i++))
    do
        echo >&3
    done
}

function close_pip_async(){
    # close fd read
    exec 3<&- 
    # close fd write
    exec 3>&- 
}

# checkout whether is download
function check_download_state(){
    local file_path=$1
    local path=$2
    local file_name=${file_path##*/}
    local local_file=${path}"/"$file_name
    local status=false;
    if [[ -s ${path}"/ok" ]]
    then
        ok_str=$(cat ${path}"/ok")
        for item in ${ok_str[@]}
        do
            if [[ $file_path == $item ]]
            then
                status=true;
                break;
            fi
        done
    fi
    if [[ ${status} && -s ${local_file} ]]
    then
        return 0;
    fi
    rm -f $local_file;
    sed -i '/'"${file_name}"'/d' ${path}"/ok"
    return 1;
}

function download_package(){
    check_download_state $1 $CACHE_PATH
    if [[ $? == 0 ]]
    then
        return
    fi

    download_file $1 $CACHE_PATH

    if [[ $? == 0 ]]
    then
        echo "$1" >> $DOWNLOAD_OK
    else
        echo "$1" >> $DOWNLOAD_ERROR
    fi
}

function download_deb(){
    check_download_state $1 $2
    if [[ $? == 0 ]]
    then
        return
    fi

    download_file $1 $2
    if [[ $? == 0 ]]
    then
        echo "$1" >> $2"/ok"
    else
        echo "$1" >> $2"/error"
    fi
}

function download_auto_packages(){
    check_download_state $1 $AUTO_PATH
    if [[ $? == 0 ]]
    then
        return
    fi

    download_file $1 $AUTO_PATH

    if [[ $? == 0 ]]
    then
        echo "$1" >> $AUTO_DOWNLOAD_OK
    else
        echo "$1" >> $AUTO_DOWNLOAD_ERROR
    fi
}
function check_error(){
    local error_file=$1
    if [ -s $error_file ]
    then
        local error=$(cat ${error_file} | tr "\n" ",")
        echo "Download packages[${error}] failed."
        read -p "to continue[Y/n]: " ins
        if [[ $ins == "n" || $ins == "N" ]]
        then
            echo "stop"
            exit 1
        fi
    fi
}
function local_board_config_name(){
    local conf_board=$(loadConf "Base" "board_config");
    echo ${conf_board##*/}
}

# download packages and deb, running ${download_num} jobs concurrently 
# param 1: path to store debs
# packages store: .cache
function download_board_packages(){
    local LOCAL_APT_PATH=$1
    mkdir -p $CACHE_PATH
    mkdir -p $AUTO_PATH
    rm -f $LOCAL_APT_PATH"/error"
    rm -f $DOWNLOAD_ERROR

    local LOCAL_APT_PATH=$1
    local conf_board=$(loadConf "Base" "board_config");
    download_file $conf_board "."
    if [[ $? != 0 ]]
    then
        log_error "Download ${conf_board} failed"
        exit 1
    fi
    conf_board=${conf_board##*/}
    local sections=$(load_section ${conf_board} "Packages")
    local sections2=$(load_section ${conf_board} "Deb")
    local sections3=$(load_section ${conf_board} "Auto")
    IFS_old=$IFS 
    IFS=$'\n'
    open_pip_async;
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_package $value
            echo >&3
        }&
    done
    for sect in ${sections2[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_deb $value $LOCAL_APT_PATH
            echo >&3
        }&
    done
    for sect in ${sections3[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_auto_packages $value
            echo >&3
        }&
    done
    wait
    close_pip_async;
    IFS=$IFS_old

    check_error $DOWNLOAD_ERROR
    check_error $LOCAL_APT_PATH"/error"
    check_error $AUTO_DOWNLOAD_ERROR
}

# install packages
function install_packages(){
    local ROOTFS_BASE=$1
    for package in ${CACHE_PATH}/*
    do
        if [[ ${package} == *".tar.gz" ]]
        then
            tar --no-same-owner -xzf ${package}  -C  ${ROOTFS_BASE}
        fi
    done
}

function run_auto_package(){
    ROOTFS_BASE=$1
    tmp_path=$2
    path=$(cd ${ROOTFS_BASE}; pwd)
    ${tmp_path}"/run.sh" $ROOTFS_BASE
}

# intsall auto packeages
# run 'run.sh' in package
function install_auto_packages(){
    local ROOTFS_BASE=$1
    for package in ${AUTO_PATH}/*
    do
        if [[ ${package} == *"tar.gz" ]]
        then
            local file_name=${package##*/}
            tmp=${AUTO_PATH}"/"${file_name%%.tar.gz}
            echo ${package}" to "${tmp}
            mkdir -p ${tmp}
            tar --no-same-owner -xzf ${package} -C ${tmp}
            run_auto_package ${ROOTFS_BASE} ${tmp}
        fi
    done
}