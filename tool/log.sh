#!/bin/bash

function check_log_path(){
    if [ ! -d "${LOG_PATH}" ]; then
        mkdir ${LOG_PATH}
    fi
}

function log_info(){
    check_log_path;
    message=$(date +"%Y-%m-%d %H:%M:%S")" : "$1
    echo -e "\033[32m $message \033[0m";
    echo $message >> ${LOG_PATH}"/info";
}

function log_error(){
    check_log_path;
    message=$(date +"%Y-%m-%d %H:%M:%S")" : "$1
    echo -e "\033[31m $message \033[0m";
    echo $message >> ${LOG_PATH}"/error";
}