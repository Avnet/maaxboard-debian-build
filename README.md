# Debian build script


## 获取board config

## 执行
sudo ./debian_build.sh -c [all/rootfs/uboot/linux] -b [board.ini]
例如
>  sudo ./debian_build.sh -c rootfs -b ../board/maaxboard-mini/maaxboard-mini-weston.ini

<font color="red">注意：</font> <font size="3">钩子中默认使用ssh clone [GitLab][gitlab] 中 uboot，kernel代码，所以需要将编译电脑key(root 用户的key，因为编译的时候使用sudo)添加到[GitLab][gitlab]</font>

[gitlab]:http://192.168.2.100