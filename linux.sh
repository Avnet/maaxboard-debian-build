#!/bin/bash

function build_linux(){
    local linux_hook=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "linux_hook");
    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})

    if [[ -z ${linux_hook} ]];then
        log_error "Not found uboot hook in "${BOARD_CONFIG_FILE}
        exit -1;
    fi

    if [[ "${linux_hook}" == "./"* ]];then
        linux_hook=${tmp_path}"/"${linux_hook:2}
    fi

    if [[ -s ${linux_hook} ]];then
        . ${linux_hook}
        local linux_dir=$PARAM_OUTPUT_DIR"/linux"
        mkdir -p $linux_dir
        pre_call_function_by_name "linux_all_build" $linux_dir
    else
        log_error ${linux_hook}" not found or empty."
    fi
}