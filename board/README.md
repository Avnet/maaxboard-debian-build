# Board Config

## Sections
- Base
- Packages
- Auto
- Deb
- Apt
- Rootfs
- Hooks
- Include
- Compile

### Base
some basic informations  
BORAD ： board name, whiche will wirte to /etc/hostname and images name  
image_sys ：Images type: Yocto/Debian  
image_version: \[versionid\]\[type\]\[buildid\]  
> versionid : such as 1.0.0  
> type : a,b,r,p  
> buildid : such as 01  
> example : 1.0.0a01  

image_type ： SDcard/emmc  
download_type : scp/wget  
download_url ：the prefix of download url
> -------------wget-----------------------------------  
> download_type=wget  
> download_url=http://192.168.2.68:8000/<file_path>  
> --------------scp-----------------------------------  
> download_type=scp  
> download_url=embest@192.168.2.134:~/rootfs  
> scp 需要添加key到下载服务器上，保证scp免密码  
> sudo ssh-keygen -t rsa  
> cat id_rsa.pub >> ~/.ssh/authorized_keys  

download_num : Concurrent download num  
images_extend_size ： N(M),the extra size of file system. File system output size = file system size + N

### Packages
some precompiled files,which can extract to file syatem by tar.
the packages will extract to the root(/)   
> tar --no-same-owner -xzf ${tar_file}  -C  ${ROOTFS_BASE}

### Auto
The difference from Packages is that contail a run.sh.
The script executes automatically，and with a parameter(ROOTFS_BASE)

### Deb
Deb Deb file prepared，available to download，which can config in Apt. 
tar.gz Multiple deb files

### Apt
Apt the package,needed to apt install(include packages config in Deb section).

### Rootfs
Some scripts, installed by 'install'
example: name_m_0644=rootfs/etc/remote_name  
download form: rootfs/etc/remote_name
save to: ${ROOTFS_BASE}/etc/name  
Make sure the same relative path to the root.
The file can be renamed.
name_m_0644， m/d : file/dir,  permission

example ： dir_d_0755=/etc/dir  
create directory ${ROOTFS_BASE}/etc/dir  

### Hooks  
apt  pre_apt_hook，post_apt_hook  
Packages pre_packages_hook，post_packages_hook  
Auto pre_auto_hook，post_auto_hook  
Rootfs pre_rootfs_hook，post_rootfs_hook  

### Include
load other ini config 

## Hooks 说明
hook has two types
- section
- key

section: auto、Packages、Apt、Rootfs  
key: board->section->key，exclude Rootfs

### section钩子 
pre_[section]_all  
post_[section]_all  

### key 钩子  
pre_[section]_[key]  
post_[section]_[key]  

<b>the first parameter of hook function is ROOTFS_BASE</b>


### Compile
gcc_hook : download gcc,and export environment variables  
> gcc_hook=./hooks/gcc_linaro_7.3.1_hook  

uboot_hook : download uboot code，and compile
> uboot_hook=./hooks/uboot_hook

linux_hook : download kernel code，and compile
>linux_hook=./hooks/linux_hook

uEnv_file : uEnv.tx 
> uEnv_file=./hooks/uEnv.txt

first_fat : first partition size
> first_fat=256

firmware ：
> firmware=./firmware

<b>Comment:</b>
> Include, Hooks, Compile could be a relative path(ini),or an absolute path

## Problem
### Encode
1. make sure files use Unix line ending

