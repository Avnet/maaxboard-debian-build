#!/bin/bash
. ./tool/log.sh
. ./tool/tool.sh

readonly GCC_OUTPUT_PATH="output_gcc"

function download_gcc(){
    local base_root=$1

    local download_url=$(loadConf "Gcc" "download_url");

    local tmp_file=${base_root}"/"${download_url##*/}
    [[ -s $tmp_file ]] && return 0;

    download_file $download_url ${base_root}
    if [[ $? != 0 ]];then
        log_error "Download Gcc failed,exit";
        exit 1;
    fi
    return 0;
}


function extract_file(){
    case $1 in
         *.tar.gz )
         echo "tar.gz";;
         *.zip )
         echo "zip";;
         *.tar )
         echo "tar";;
         *.tar.bz2 )
         echo ".tar.bz2";;
         *.tar.xz )
         echo ".tar.xz";;
         *.rar )
         echo ".rar";;
         *.gz )
         echo ".gz";;
         *.bz2 )
         echo ".bz2";;
    esac
}

function build_gcc(){
    local base_root=$1
    download_gcc;
     local download_url=$(loadConf "Gcc" "download_url");
     local gcc_name=${download_url##*/}
     gcc_name=${gcc_name%}


}