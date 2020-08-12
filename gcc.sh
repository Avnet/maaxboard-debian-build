#!/bin/bash

readonly GCC_OUTPUT_PATH=${PARAM_OUTPUT_DIR}"/gcc"

function prepare_gcc(){
    local gcc_hook=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "gcc_hook");
    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})

    if [[ -z ${gcc_hook} ]];then
        log_error "Not found gcc hook in "${BOARD_CONFIG_FILE}
        exit -1;
    fi
    if [[ "${gcc_hook}" == "./"* ]];then
        gcc_hook=${tmp_path}"/"${gcc_hook:2}
    fi

    if [[ -s ${gcc_hook} ]];then
        . ${gcc_hook}
        mkdir -p $GCC_OUTPUT_PATH
        pre_call_function_by_name "gcc_all_build" $GCC_OUTPUT_PATH
    else
        log_error ${gcc_hook}" not found or empty."
    fi
}