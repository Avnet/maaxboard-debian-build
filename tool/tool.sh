#!/bin/bash
CONFIG_FILE=./config.ini

# read config.ini
# param 1: Section
# param 2: Name
function loadConf(){
    local SECTION=$1;
    local CONFIG=$2;
    local value=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$CONFIG'/{print $2;exit}' $CONFIG_FILE`
    echo $value;
}

# read ini config file
# param 1: config file
# param 2: Section
# param 3: Name
function load_config_file(){
    local FILE=$1
    local SECTION=$2;
    local CONFIG=$3;
    local value=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$CONFIG'/{print $2;exit}' $FILE`
    echo $value;
}

# load config sections
# param 1: file
# param 2: section
function load_section(){
    local m_file=$1
    local m_section=$2
    local is_start=false
    IFS_old=$IFS 
    IFS=$'\n' 
    while read line
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
    done < $m_file
    # echo ${sections[*]}
    IFS=$IFS_old 
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
    local _name=\${1}
    local repeated_cnt=5;
    local RET_CODE=1;

    log_info " Installing \${_name}";
    for (( c=0; c<\${repeated_cnt}; c++ ))
    do
        apt install -y \${_name} && {
            RET_CODE=0;
            break;
        };

        echo
        echo "##########################"
        echo "## Fix missing packages ##"
        echo "##########################"
        echo

        sleep 2;

        apt --fix-broken install -y && {
            RET_CODE=0;
            break;
        };

        echo "##########################"
        echo "FIX error processing package XXX (--configure)"
        echo "##########################"
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

    return \${RET_CODE}
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