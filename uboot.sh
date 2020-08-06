#!/bin/bash
. ./tool/log.sh
. ./tool/tool.sh

readonly UBOOT_OUTPUT_PATH="output_uboot"

function download_make_file(){
    local base_root=$1
    local make_file=$(loadConf "Uboot" "make_file");
    download_file $make_file $base_root
    [[ $ret != 0 ]] && {
        log_error "Download make_file failed,exit."
        exit 1;
    }
    . ${base_root}"/"${make_file%/*}
    log_info "load: "${base_root}"/"${make_file%/*}
}

function compile_uboot(){
	local base_root=$1
    cd $base_root
    local git_url=$(loadConf "Uboot" "git_url");
    local git_name=${git_url##*/}
    git_name=${git_name%.git}
    cd $git_name

    local func=$(loadConf "Uboot" "make_function");
    local make_j=$(loadConf "Uboot" "make_j");
    ${func} ${base_root}"/"${UBOOT_OUTPUT_PATH} $make_j
}

function build_uboot(){
    local base_root=$1
    mkdir -p $base_root
    cd base_root;
    local git_url=$(loadConf "Uboot" "git_url");
    local git_tag=$(loadConf "Uboot" "git_tag");
    git clone -b ${git_tag} ${git_url}

    local git_name=${git_url##*/}
    git_name=${git_name%.git}

    cd $git_name
    VERSION=`grep ^VERSION Makefile | cut -d' ' -f3`
    PATCHLEVEL=`grep ^PATCHLEVEL Makefile | cut -d' ' -f3`
    SUBLEVEL=`grep ^SUBLEVEL Makefile | cut -d' ' -f3`
    commitid=`git log --oneline -1 | cut -d' ' -f1`
    cd ..
    git archive --prefix=u-boot/ -o u-boot_"${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"_"{$git_tag}"_"${commitid}".tar.gz HEAD
}


