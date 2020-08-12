#!/bin/bash

# check whether  rootfs img exits and greater than 500M
function check_rootfs(){
    if [[ -s ${G_ROOTFS_IMAGE_PATH} ]];then
        local rootfs_img_size=$(ls -l ${G_ROOTFS_IMAGE_PATH} | awk '{print $5}')
        if [ $rootfs_img_size -gt 524288000 ];then
            log_info $G_ROOTFS_IMAGE_PATH" already exists"
            return 0;
        fi
    fi

    cmd_make_rootfs
}

function check_uboot(){
    local uboot_imx=$PARAM_OUTPUT_DIR"/uboot/u-boot.imx"
    if [[ -s ${uboot_imx} ]];then
        log_info "uboot already complete"
        return 0
    fi

    cmd_make_uboot
}

function check_linux(){
    local linux_image=$PARAM_OUTPUT_DIR"/linux/Image"
    local linux_dtbs_num=$(ls -la ${PARAM_OUTPUT_DIR}/linux/*.dtb | wc -l)


    if [[ -s ${linux_image} ]];then
        if [ $linux_dtbs_num -gt 0 ];then
            log_info "linux already complete"
            return 0
        fi
    fi

    cmd_make_linux
}



function first_fat(){
    log_info "start make first fat...."
    local image_dir=$1
    
    dd if=/dev/zero of=boot_fatsd.img bs=1M count=$2
    mkfs.vfat boot_fatsd.img

    local first_fat_dir=${image_dir}"/first_fat_mount"
    mkdir -p $first_fat_dir
    mount boot_fatsd.img $first_fat_dir

    cp $PARAM_OUTPUT_DIR"/linux/Image" $first_fat_dir
    cp $PARAM_OUTPUT_DIR/linux/*.dtb $first_fat_dir

    # uEnv.txt
    local uEnv_file=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "uEnv_file");
    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})

    if [[ -z ${uEnv_file} ]];then
        log_error "Not found uboot hook in "${BOARD_CONFIG_FILE}
        exit -1;
    fi

    if [[ "${uEnv_file}" == "./"* ]];then
        uEnv_file=${tmp_path}"/"${uEnv_file:2}
    fi

     if [[ -s ${uEnv_file} ]];then
        cp ${uEnv_file} $first_fat_dir
    else
        log_error ${uEnv_file}" not found or empty."
    fi

    sync
    umount $first_fat_dir
    log_info "first fat done."
}

function buidl_images(){
    local tmp_dir=$(pwd)
    check_rootfs
    check_uboot
    check_linux

    local first_fat_size=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "first_fat");
    local image_dir=${PARAM_OUTPUT_DIR}"/image"
    mkdir -p $image_dir
    cd $image_dir
    first_fat $image_dir $first_fat_size

    local size1=`du -sm boot_fatsd.img | cut -f1`
    # local size2=`du -sm ${G_ROOTFS_IMAGE_PATH} | cut -f1`
    local size2=$(ls -la ${G_ROOTFS_IMAGE_PATH} | awk '{print $5}')
    size2=`expr $size2 / 1048576`
    local size=`expr $size1 + $size2 + 10`

    local BORAD=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "BORAD");
    local sys_version=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "image_sys");
    local version=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "image_version");
    local image_type=$(load_config_file2 ${BOARD_CONFIG_FILE} "Base" "image_type");
    local images_name="${BORAD}-${sys_version}-Image-${image_type}-${version}"

    log_info "create "${images_name}.img" size: "${size}"M"
    dd if=/dev/zero of=${images_name}.img bs=1M count=$size
    local second_fat_start=`expr ${first_fat_size} \* 2048`
    second_fat_start=`expr $second_fat_start + 20480`
    echo -e "o\nn\np\n1\n20480\n+${first_fat_size}M\na\nt\nc\nn\np\n2\n${second_fat_start}\n\nw\n" | sudo fdisk ${images_name}.img

    log_info "image partition..."
    losetup /dev/loop3 ${images_name}.img
    kpartx -avs /dev/loop3

    dd if=${PARAM_OUTPUT_DIR}"/uboot/u-boot.imx" of=/dev/loop3 bs=1k seek=33 conv=fsync
    dd if=boot_fatsd.img of=/dev/mapper/loop3p1
    dd if=${G_ROOTFS_IMAGE_PATH} of=/dev/mapper/loop3p2

    log_info "install firmware..."
    local rootfs_mnt=${image_dir}"/rootfs"
    mkdir -p $rootfs_mnt
    mount /dev/mapper/loop3p2 $rootfs_mnt

    local firmware=$(load_config_file2 ${BOARD_CONFIG_FILE} "Compile" "firmware");
    local tmp_path=$(get_file_path ${BOARD_CONFIG_FILE})
    if [[ ! -z ${firmware} ]];then
        if [[ "${firmware}" == "./"* ]];then
           firmware=${tmp_path}"/"${firmware:2}
        fi
        if [[ -d ${firmware} ]];then
            cp -af ${firmware} ${rootfs_mnt}/lib/
        fi
    fi
    
    cp -af ${PARAM_OUTPUT_DIR}/linux/modules/*  $rootfs_mnt
    sync

    umount $rootfs_mnt

    kpartx -d /dev/loop3
    losetup -d /dev/loop3

    mv ${images_name}.img $LINUX_IMG_OUTPUT
    log_info "release ${LINUX_IMG_OUTPUT}/${images_name}.img finished" 
    cd $tmp_dir
}