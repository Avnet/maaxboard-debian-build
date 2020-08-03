# Board 配置

## Sections
- Packages
- Auto
- Deb
- Apt
- Rootfs
- Hooks
- Include

### Packages
编译好的文件，并且按照文件系统中的目录组织的tar包。  
脚本解压tar包到安装根目录  
> tar --no-same-owner -xzf ${tar_file}  -C  ${ROOTFS_BASE}

### Auto
也是tar包的形式，与Packages不同之处在与 Auto中有run.sh脚本。  
Auto 主要是执行run.sh脚本，传递一个参数：安装根目录(ROOTFS_BASE)  

Auto 适合处理Qt之类的，需要些额外动作，例如配置 qt plugin路径、lib 路径等。

### Deb
Deb 是一些已经编译好的包，提供下载，具体安装在Apt中配置

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

需要注意的Hooks不会加载include中的内容。  

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