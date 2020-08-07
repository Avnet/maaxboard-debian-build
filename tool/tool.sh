#!/bin/bash

# read config.ini
# param 1: Section
# param 2: Name
function loadConf(){
    local SECTION=$1;
    local CONFIG=$2;
    if [[ -f $CONFIG_FILE ]];then
        local value=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$CONFIG'/{print $2;exit}' $CONFIG_FILE`
        echo $value;
    fi
}

# read ini config file
# param 1: config file
# param 2: Section
# param 3: Name
function load_config_file(){
    local FILE=$1
    local SECTION=$2;
    local CONFIG=$3;

    if [[ ! -f $FILE ]];then
        if [[ -f ${ABSOLUTE_DIRECTORY}"/"$FILE ]];then
            FILE=${ABSOLUTE_DIRECTORY}"/"$FILE
        else
            return 1
        fi
    fi
    if [[ -f $FILE ]];then
        local value=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$CONFIG'/{print $2;exit}' $FILE`
        echo $value;
    fi
}

function load_config_file2(){
    local FILE=$1
    local SECTION=$2;
    local CONFIG=$3;
    local value=$(load_config_file $FILE $SECTION $CONFIG)
    if [ -n "$value" ];then
        echo $value;
        return 0;
    fi
    
    local includes=$(load_section $FILE "Include")
    IFS_old=$IFS 
    IFS=$'\n'
    for sect in ${includes[@]}
    do
        # sub_file=$(parse_config_value $sect)
        sub_file=${sect##*/}
        # load_section2 $sub_file $m_section
        load_config_file2 $sub_file $SECTION $CONFIG
        if [[ $? == 0 ]];then
            return 0;
        fi
    done
    IFS=$IFS_old

    return 1;
}

# load config sections
# param 1: file
# param 2: section
function load_section(){
    local m_file=$1
    local m_section=$2
    local is_start=false
    if [[ ! -f $m_file ]];then
        if [[ -f ${ABSOLUTE_DIRECTORY}"/"$m_file ]];then
            m_file=${ABSOLUTE_DIRECTORY}"/"$m_file
        else
            return 1;
        fi
    fi
    local lines=$(cat $m_file)
    [[ -z lines ]] && return 0;
    IFS_old=$IFS 
    IFS=$'\n' 
    for line in ${lines[@]}
    do
        if [[ $line == "#"* ]]
        then
            continue;
        fi
        if [[ $line == "["*"]"* ]]
        then
            is_start=false;
        fi
        if $is_start 
        then
            # sections[${#sections[*]}]=$line
             echo $line
        fi
        if [[ $line == "["$m_section"]"* ]]
        then
            is_start=true;
        fi
    done
    # echo ${sections[*]}
    IFS=$IFS_old 
}

# Recursive call to load section
function load_section2(){
    local m_file=$1
    local m_section=$2
    # echo $m_file" start load includes"
    local includes=$(load_section $m_file "Include")
    if [[ -n $includes ]];then
        IFS_old=$IFS 
        IFS=$'\n'
        for sect in ${includes[@]}
        do

            # sub_file=$(parse_config_value $sect)
            sub_file=${sect##*/}
            # load_section2 $sub_file $m_section
            load_section2 $sub_file $m_section
        done
        IFS=$IFS_old
    fi
    # load_section $m_file $m_section
    # data=$(load_section $m_file $m_section)
    # echo $data
    load_section $m_file $m_section
}

# parse config line name
function parse_config_key(){
    local line=$1
    echo ${line%%=*}
}
# parse config line value
function parse_config_value(){
    local line=$1
    echo ${line#*=}
}

# apt install
# Retry 5 times,when failed
function protected_install()
{
    local _name=$1
    local repeated_cnt=5;
    local RET_CODE=1;

    log_info " Installing ${_name}";
    for (( c=0; c<${repeated_cnt}; c++ ))
    do
        apt install -y ${_name} && {
            RET_CODE=0;
            break;
        };

        log_info "##########################"
        log_info "## Fix missing packages ##"
        log_info "##########################"
        log_info

        sleep 2;

        apt --fix-broken install -y && {
            RET_CODE=0;
            break;
        };

        log_info "##########################"
        log_info "FIX error processing package XXX (--configure)"
        log_info "##########################"
        sleep 2;
        
        cp -fr /var/lib/dpkg/info/* /var/lib/dpkg/info_old/
        rm -fr /var/lib/dpkg/info/*
        apt update
        apt -f install && {
            cp -fr /var/lib/dpkg/info/* /var/lib/dpkg/info_old/
            cp -fr /var/lib/dpkg/info_old/* /var/lib/dpkg/info/
            
            RET_CODE=0;
            break;
        };

    done

    return ${RET_CODE}
}

# download file
# config.ini base_url
# param 1: relative path
# param 2: target path
# return 0: ok; >0 : failed
function download_file(){
    local file_path=$1;
    local file_name=${file_path##*/}
    local target_path=$2
    local base_url=$(loadConf "Base" "download_url");
    # echo $base_url
    local base_url2=${base_url/%"<file_path>"/$file_path}
    log_info $base_url2
    # echo $base_url2
    wget $base_url2 -O ${target_path}"/"${file_name}
    ret=$?
    if [ $ret == 0 ]
    then
        log_info "${file_path} download ok"
    else
        log_error "${file_path} download failed"
    fi
    return $ret;
}

function conf_download_file(){
    local file_path=$1;
    local file_name=${file_path##*/}
    local target_path=$2
    local base_url=$(loadConf "Base" "conf_download_url");
    # echo $base_url
    local base_url2=${base_url/%"<file_path>"/$file_path}
    log_info $base_url2
    # echo $base_url2
    wget $base_url2 -O ${target_path}"/"${file_name}
    ret=$?
    if [ $ret == 0 ]
    then
        log_info "${file_path} download ok"
    else
        log_error "${file_path} download failed"
    fi
    return $ret;
}

function is_function_exist(){
    local func=$1
    local ret=1;
    local func_ret="$(typeset -F $func)"

    if [[ -n $func_ret ]];then
        if [[ $func_ret == $func ]];then
            echo "0"
            return;
        fi
    fi
    echo "1"
}

function pre_call_function(){
    local section=$2
    local key=$3
    local ROOTFS_BASE=$1
    local func_name="pre_${section}_${key}"

    local status=$(is_function_exist $func_name)

    if [[ $status == "0" ]];then
        log_info "[${section}] ${key}: pre call"
        ${func_name} $ROOTFS_BASE
    fi
}

function post_call_function(){
    local section=$2
    local key=$3
    local ROOTFS_BASE=$1
    local func_name="post_${section}_${key}"

    local status=$(is_function_exist $func_name)
    if [[ $status == "0" ]];then
        log_info "[${section}] ${key}: post call"
        ${func_name} $ROOTFS_BASE
    fi
}