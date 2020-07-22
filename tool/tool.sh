#!/bin/bash
CONFIG_FILE=./config.ini

function loadConf(){
    SECTION=$1;
    CONFIG=$2;
    value=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$CONFIG'/{print $2;exit}' $CONFIG_FILE`
    echo $value;
}

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