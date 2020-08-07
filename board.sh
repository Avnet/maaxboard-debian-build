#!/bin/bash

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

function download_common(){
    local file_path=$1
    local path=$2
    local file_name=${file_path##*/}
    local local_file=${path}"/"$file_name
    local status=0;
    if [[ -s ${path}"/ok" ]]
    then
        ok_str=$(cat ${path}"/ok")
        for item in ${ok_str[@]}
        do
            if [[ $file_path == $item ]]
            then
                status=1;
                break;
            fi
        done
    fi
    if [[ ${status} == 1 && -s ${local_file} ]]
    then
        return 0;
    fi
    if [[ ${status} == 1 && ! -s ${local_file} ]] ; then
        sed -i '/'"${file_name}"'/d' ${path}"/ok"
    fi
    rm -f $local_file;

    log_info "start download "$1
    download_file $1 $2
    if [[ $? == 0 ]]
    then
        echo "$1" >> $2"/ok"
    else
        echo "$1" >> $2"/error"
    fi
}

function download_rootfs(){
    local file_path=$1
    local tmp_file_path=${file_path#*/}
    local tmp_path=$TMP_ROOTFS_PATH"/"${tmp_file_path%/*}
    mkdir -p $tmp_path

    download_file $file_path $tmp_path
    
    if [[ $? != 0 ]];then
        echo "$file_path" >> $TMP_ROOTFS_PATH"/error"
    fi
}

function check_error(){
    local error_file=$1
    ret=0;
    if [ -s $error_file ]
    then
        ret=1;
        local error=$(cat ${error_file} | tr "\n" ",")
        echo "Download packages[${error}] failed."
        read -p "to continue[Y/n]: " ins
        if [[ $ins == "n" || $ins == "N" ]]
        then
            echo "stop"
            exit 1
        fi
    fi
    return $ret
}

function get_board_config_name(){
    local conf_board=$(loadConf "Base" "board_config");
    echo ${conf_board##*/}
}

function download_hooks(){
    local board_hook=$1
    local board_hook_file=${board_hook##*/}
    if [ ! -s ${HOOKS_PATH}"/"$board_hook_file ]
    then
        conf_download_file $board_hook ${HOOKS_PATH}
        if [[ $? != 0 ]]
        then
            log_error "Download ${board_hook} failed"
            exit 1
        fi
    fi
}

# Recursive call to download board config
function download_board_ini(){
    local conf_board=$1
    local conf_board_file=${conf_board##*/}
    if [ ! -s ${ABSOLUTE_DIRECTORY}"/"$conf_board_file ]
    then
        conf_download_file $conf_board ${ABSOLUTE_DIRECTORY}
        if [[ $? != 0 ]]
        then
            log_error "Download ${conf_board} failed"
            exit 1
        fi
    fi

    local sections=$(load_section ${conf_board_file} "Include")
    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        download_board_ini $value
    done
    IFS=$IFS_old
}

# download packages and deb, running ${download_num} jobs concurrently 
# param 1: path to store debs
# packages store: .cache
function download_board_packages(){
    local LOCAL_APT_PATH=$1
    mkdir -p $PACKAGES_PATH
    mkdir -p $AUTO_PATH
    rm -f $LOCAL_APT_PATH"/error"
    rm -f $AUTO_PATH"/error"
    rm -f $TMP_ROOTFS_PATH"/error"
    rm -f $PACKAGES_PATH"/error"

    local LOCAL_APT_PATH=$1
    local conf_board=$(loadConf "Base" "board_config");
    local conf_board_file=${conf_board##*/}
    download_board_ini $conf_board
    # if [ ! -s $conf_board_file ]
    # then
    #     download_file $conf_board "."
    #     if [[ $? != 0 ]]
    #     then
    #         log_error "Download ${conf_board} failed"
    #         exit 1
    #     fi
    # fi
    local sections=$(load_section2 ${conf_board_file} "Packages")
    local sections2=$(load_section2 ${conf_board_file} "Deb")
    local sections3=$(load_section2 ${conf_board_file} "Auto")
    local sections4=$(load_section2 ${conf_board_file} "Rootfs")
    local sections5=$(load_section ${conf_board_file} "Hooks")
    IFS_old=$IFS 
    IFS=$'\n'
    open_pip_async;
    mkdir -p $PACKAGES_PATH
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_common $value $PACKAGES_PATH
            echo >&3
        }&
    done
    echo "after packages"
    for sect in ${sections2[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_common $value $LOCAL_APT_PATH
            if [[ $value == *".tar.gz" ]];then
                tar_file=${LOCAL_APT_PATH}"/"${value##*/}
                tar -zxf $tar_file -C $LOCAL_APT_PATH
            fi
            echo >&3
        }&
    done
    echo "after deb"
    mkdir -p $AUTO_PATH
    for sect in ${sections3[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_common $value $AUTO_PATH
            echo >&3
        }&
    done
    echo "after auto"
    for sect in ${sections4[@]}
    do
        value=$(parse_config_value $sect)
        key=$(parse_config_key $sect)
        model=${key:0-7}
        [[ $model == "_d_"* ]] && continue
        read -u3
        {
            download_rootfs $value
            echo >&3
        }&
    done
    mkdir -p $HOOKS_PATH
    for sect in ${sections5[@]}
    do
        value=$(parse_config_value $sect)
        read -u3
        {
            download_hooks $value
            echo >&3
        }&
    done
    wait
    close_pip_async;
    IFS=$IFS_old

    check_error $PACKAGES_PATH"/error"
    check_error $LOCAL_APT_PATH"/error"
    if [[ $? != 0 ]]
    then
        log_error "download debs failed,stop."
        exit 1;
    fi
    check_error $AUTO_PATH"/error"
    check_error $TMP_ROOTFS_PATH"/error"
    if [[ $? != 0 ]]
    then
        log_error "download rootfs failed,stop."
        exit 1;
    fi

    check_error $HOOKS_PATH"/error"
    if [[ $? != 0 ]]
    then
        log_error "download Hooks failed,stop."
        exit 1;
    fi
}

# install packages
function install_packages(){
    local ROOTFS_BASE=$1
    local conf_board_file=$(get_board_config_name);
    local sections=$(load_section2 ${conf_board_file} "Packages");
    
    pre_call_function ${ROOTFS_BASE} "Packages" "all"
    
    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        key=$(parse_config_key $sect)
        tar_file=${PACKAGES_PATH}"/"${value##*/}
        log_info "install package: "$tar_file

        pre_call_function ${ROOTFS_BASE} "Packages" ${key}
        tar --no-same-owner -xzf ${tar_file}  -C  ${ROOTFS_BASE}
        post_call_function ${ROOTFS_BASE} "Packages" ${key}
    done
    IFS=$IFS_old

    post_call_function ${ROOTFS_BASE} "Packages" "all"
    # for package in ${PACKAGES_PATH}/*
    # do
    #     if [[ ${package} == *".tar.gz" ]]
    #     then
    #         log_info "install package: "$package
    #         tar --no-same-owner -xzf ${package}  -C  ${ROOTFS_BASE}
    #     fi
    # done
}

function run_auto_package(){
    local ROOTFS_BASE=$1
    local tmp_path=$2
    local path=$(cd ${ROOTFS_BASE}; pwd)
    ${tmp_path}"/run.sh" $ROOTFS_BASE
}

# intsall auto packeages
# run 'run.sh' in package
function install_auto_packages(){
    local ROOTFS_BASE=$1
    local conf_board_file=$(get_board_config_name);
    local sections=$(load_section2 ${conf_board_file} "Auto");

    pre_call_function ${ROOTFS_BASE} "Auto" "all"

    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        key=$(parse_config_key $sect)
        file_name=${value##*/}
        tar_file=${AUTO_PATH}"/"${value##*/}
        log_info "install auto package: "$tar_file
        tmp=${AUTO_PATH}"/"${file_name%%.tar.gz}
        mkdir -p ${tmp}

        pre_call_function ${ROOTFS_BASE} "Auto" ${key}
        tar --no-same-owner -xzf ${tar_file} -C ${tmp}
        run_auto_package ${ROOTFS_BASE} ${tmp}
        post_call_function ${ROOTFS_BASE} "Auto" ${key}
    done
    IFS=$IFS_old

    post_call_function ${ROOTFS_BASE} "Auto" "all"
    # for package in ${AUTO_PATH}/*
    # do
    #     if [[ ${package} == *"tar.gz" ]]
    #     then
    #         local file_name=${package##*/}
    #         log_info "install auto packages: "$file_name
    #         tmp=${AUTO_PATH}"/"${file_name%%.tar.gz}
    #         mkdir -p ${tmp}
    #         tar --no-same-owner -xzf ${package} -C ${tmp}
    #         run_auto_package ${ROOTFS_BASE} ${tmp}
    #     fi
    # done
}

function install_apt(){
    local ROOTFS_BASE=$1
    local conf_board=$(load_config_file ${ROOTFS_BASE}"/config.ini" "Base" "board_config");
    local conf_board_file=${conf_board##*/};
    
    local sections=$(load_section2 ${ROOTFS_BASE}"/"${conf_board_file} "Apt");
    local name;
    local value;

    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        log_info "apt install : "$sect
        name=$(parse_config_key $sect)
        value=$(parse_config_value $sect)

        pre_call_function ${ROOTFS_BASE} "Apt" ${name}
        [[ ! -z $value && $value == "true" ]] && protected_install $name
        post_call_function ${ROOTFS_BASE} "Apt" ${name}
    done
    IFS=$IFS_old
}

function install_rootfs(){
    local ROOTFS_BASE=$1
    local conf_board_file=$(get_board_config_name);

    local sections=$(load_section2 ${conf_board_file} "Rootfs")

    pre_call_function ${ROOTFS_BASE} "Rootfs" "all"
    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        value=$(parse_config_value $sect)
        key=$(parse_config_key $sect)
  
        pre_call_function ${ROOTFS_BASE} "Rootfs" $key
        
        model=${key:0-7}
        m=${key:0-4}

        if [[ $model == "_d_"* ]]; then
            log_info "install -d "${ROOTFS_BASE}"/"$value
            install -m ${m} -d ${ROOTFS_BASE}"/"$value
        elif [[ $model == "_m_"* ]]; then
            num=${#key}-7
            name=${key:0:num}
            tmp_path=${value#*/}
            tmp_file=$TMP_ROOTFS_PATH"/"${tmp_path}
            tmp_path=${tmp_path%/*}
            mkdir -p ${ROOTFS_BASE}"/"$tmp_path
            log_info "install "${m}" "${tmp_file}"  "${ROOTFS_BASE}"/"${tmp_path}"/"${name}
            install -m ${m} ${tmp_file} ${ROOTFS_BASE}"/"${tmp_path}"/"${name}
        fi

        post_call_function ${ROOTFS_BASE} "Rootfs" $key
    done
    IFS=$IFS_old

    post_call_function ${ROOTFS_BASE} "Rootfs" "all"
}

function load_hooks(){
    local conf_board_file=$(get_board_config_name);
    local sections=$(load_section2 ${conf_board_file} "Hooks");
    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${sections[@]}
    do
        board_hook=$(parse_config_value $sect)
        if [[ -s ${HOOKS_PATH}"/"${board_hook##*/} ]];then
            . ${HOOKS_PATH}"/"${board_hook##*/}
        fi
    done
    IFS=$IFS_old
}