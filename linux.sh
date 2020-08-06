#bin/bash

. ./tool/log.sh
. ./tool/tool.sh

readonly LINUX_OUTPUT_PATH="output_linux"

function compile_linux(){
    local base_root=$1
    cd $base_root
    local git_url=$(loadConf "Linux" "git_url");
    local git_name=${git_url##*/}
    git_name=${git_name%.git}
    cd $git_name

    local func=$(loadConf "Linux" "make_function");
    local make_j=$(loadConf "Linux" "make_j");
    ${func} ${base_root}"/"${LINUX_OUTPUT_PATH} $make_j
}

function build_linux(){
    local base_root=$1
    mkdir -p $base_root
    cd base_root;
    local git_url=$(loadConf "Linux" "git_url");
    local git_tag=$(loadConf "Linux" "git_tag");
    git clone -b ${git_tag} ${git_url}

    local git_name=${git_url##*/}
    git_name=${git_name%.git}

    cd $git_name
    VERSION=`grep ^VERSION Makefile | cut -d' ' -f3`
    PATCHLEVEL=`grep ^PATCHLEVEL Makefile | cut -d' ' -f3`
    SUBLEVEL=`grep ^SUBLEVEL Makefile | cut -d' ' -f3`
    branch=`git branch | cut -d' ' -f2`
    commitid=`git log --oneline -1 | cut -d' ' -f1`

    cd ..
    git archive --prefix=linux/ -o linux_"${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"_"{$git_tag}"_"${commitid}".tar.gz HEAD;;

    cd $git_name
    compile_linux;
}