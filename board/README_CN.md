# Board 配置

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
配置一些基本信息  
BORAD ： board name，会写到/etc/hostname 和 镜像名  
image_sys ：镜像类别 Yocto/Debian  
image_version: 版本 \[versionid\]\[type\]\[buildid\]  
> versionid : such as 1.0.0  
> type : a,b,r,p  
> buildid : such as 01  
> example : 1.0.0a01  

image_type ： SDcard/emmc  
download_type : 下载方式 scp/wget  
download_url ： 下载对应路径 embest@192.168.2.134:~/rootfs  
> -------------wget-----------------------------------  
> download_type=wget  
> download_url=http://192.168.2.68:8000/<file_path>  
> --------------scp-----------------------------------  
> download_type=scp  
> download_url=embest@192.168.2.134:~/rootfs  
> scp 需要添加key到下载服务器上，保证scp免密码  
> sudo ssh-keygen -t rsa  
> cat id_rsa.pub >> ~/.ssh/authorized_keys  

download_num : 同时下载进程  
images_extend_size ： 文件系统额外指定大小N(M),文件系统输出大小=文件系统大小+N  

### Packages
编译好的文件，并且按照文件系统中的目录组织的tar包。  
脚本解压tar包到安装根目录  
> tar --no-same-owner -xzf ${tar_file}  -C  ${ROOTFS_BASE}

### Auto
也是tar包的形式，与Packages不同之处在与 Auto中有run.sh脚本。  
Auto 主要是执行run.sh脚本，传递一个参数：安装根目录(ROOTFS_BASE)  

### Deb
Deb 是一些已经编译好的包，提供下载，具体安装在Apt中配置  
tar.gz 下载自动解压(不要在包中创建目录，包中只是deb文件)

### Apt
Apt 中是需要apt 安装的包，可以是Deb 中配置的Deb包

### Rootfs
一些脚本文件或者程序，使用 install安装  
例如： name_m_0644=rootfs/etc/remote_name  
脚本会在下载rootfs/etc/remote_name，保存为${ROOTFS_BASE}/etc/name  
其中保证路径与下载文件中rootfs下的路径一致，并重命名为name  
name_m_0644 中_m_0644表示文件 权限为644  

另外对文件夹处理：  
例如 ： dir_d_0755=/etc/dir  
表示创建 文件夹 ${ROOTFS_BASE}/etc/dir  
dir_d_0755 中_d_0755 表示文件夹权限755  

### Hooks
触发脚本  
apt 安装触发 pre_apt_hook，post_apt_hook  
Packages 安装触发：pre_packages_hook，post_packages_hook  
Auto 安装触发： pre_auto_hook，post_auto_hook  
Rootfs安装触发：pre_rootfs_hook，post_rootfs_hook  

### Include
可以include 其他ini配置。  
其中配置加载顺序：先include文件.  

## Hooks 说明
hook 分为两类钩子
- section
- key

section: auto、Packages、Apt、Rootfs  
key: board配置中section 对应的key，不包括Rootfs

### section钩子
分为section的开始和结束钩子  
pre_[section]_all  
post_[section]_all  

### key 钩子
分为function开始和结束  
pre_[section]_[key]  
post_[section]_[key]  

注意Rootfs只会触发section钩子 函数  
<b>钩子函数第一个参数是 ROOTFS_BASE</b>


### Compile
gcc_hook : gcc 对应钩子  
> gcc_hook=./hooks/gcc_linaro_7.3.1_hook  

uboot_hook : uboot 对应钩子，完成uboot 获取源码，编译输出  
> uboot_hook=./hooks/uboot_hook

linux_hook : linux 对应钩子，完成linux Image/dtb 获取源码，编译输出  
>linux_hook=./hooks/linux_hook

uEnv_file : uEnv.tx 文件
> uEnv_file=./hooks/uEnv.txt

first_fat : 第一分区大小
> first_fat=256

firmware ： 固件
> firmware=./firmware

<b>注意:</b>
> Include, Hooks, Compile 可以是相等路径(相对ini)，也饿一是绝对路径

## 问题
### 编码问题
1. 确保文件是Unix line ending

