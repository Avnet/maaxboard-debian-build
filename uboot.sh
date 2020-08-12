#!/bin/bash

function build_uboot(){
    local uboot_hook=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "uboot_hook");
    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})

    if [[ -z ${uboot_hook} ]];then
        log_error "Not found uboot hook in "${BOARD_CONFIG_FILE}
        exit -1;
    fi

    if [[ "${uboot_hook}" == "./"* ]];then
        uboot_hook=${tmp_path}"/"${uboot_hook:2}
    fi

    if [[ -s ${uboot_hook} ]];then
        . ${uboot_hook}
        local uboot_dir=$PARAM_OUTPUT_DIR"/uboot"
        mkdir -p $uboot_dir
        pre_call_function_by_name "uboot_all_build" $uboot_dir
    else
        log_error ${uboot_hook}" not found or empty."
    fi
}