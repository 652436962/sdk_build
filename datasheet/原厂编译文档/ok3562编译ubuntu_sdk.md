ubuntu22.04安装工具包
forlinx@ubuntu:~$ sudo apt-get update
forlinx@ubuntu:~$ sudo apt-get install openssh-server vim git fakeroot make automake autoconf libtool libssl-dev bc dosfstools mtools parted iproute2 kmod libyaml-dev device-tree-compiler python-pip flex bison build-essential u-boot-tools libncurses-dev lib32stdc++6 lib32z1 libc6:i386 e2fsprogs scons libgmp-dev libmpc-dev



拷贝源码

forlinx@ubuntu:~$ cd /home/forlinx/work														//切换到工作目录
forlinx@ubuntu:~/work$ cat OK3562-linux-source.tar.bz2.* > OK3562-linux-source.tar.bz2
forlinx@ubuntu:~/work$ tar -xvf OK3562-linux-source.tar.bz2				//在当然位置解压压缩包

全编译测试
forlinx@ubuntu:~$ cd /home/forlinx/work/OK3562-linux-source
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh all

执行后会有选项输入，输入6后按回车继续。
1. OK3562-UP4-linux_defconfig
2. forlinx_defconfig
3. forlinx_ok3562_linux_defconfig
4. forlinx_ok3562_linux_mcu_defconfig
5. forlinx_ok3562_linux_rtos_defconfig
6. forlinx_ok3562_ubuntu22_defconfig
Which would you like? [1]: 6


编译成功后，将在rockdev文件夹下生成对应的镜像文件
forlinx@ubuntu: ~/work/OK3562-linux-source$ ls rockdev
⚠️ 注意：update.img为打包好用于OTG或者TF卡完全烧写用，其它文件为分步烧写使用

4.2.2 单独编译测试
#配置sdk
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh defconfig:forlinx_ok3562_ubuntu22_defconfig       

#生成uboot.img，生成路径为u-boot/uboot.img
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh uboot

#生成boot.img，生成路径为kernel/boot.img
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh kernel 

#生成rootfs.img，生成路径为buildroot/output/OK3562_Linux/image/rootfs.ext2
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh rootfs

#使用上述路径的uboot.img boot.img rootfs.ext2 生成update.img 路径为 rockdev/update.img 
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh updateimg

单独编译成功后update.img里的内核不更新。请分步烧写相应文件，或者重新生成update.img。
若需要使用图形配置界面配置内核，可直接执行下列命令：
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh kconfig
在弹出的图形界面中完成配置后保存退出，新配置会自动生成新的OK3562_Linux_defconfig。

清除编译生成的文件
⚠️ 注意：uboot没有开源，只有镜像。
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh clean:kernel    		#清除kernel
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh clean:rootfs   		#清除rootfs
forlinx@ubuntu: ~/work/OK3562-linux-source$ ./build.sh clean:recovery  		#清除recovery


应用编译器
forlinx@ubuntu: ~/work/OK3562-linux-source/app/forlinx/forlinx_cmd_demo/fltest_watchdog$ export PATH=/opt/aarch64-buildroot-linux-gnu_sdk-buildroot/usr/bin:$PATH
forlinx@ubuntu: ~/work/OK3562-linux-source/app/forlinx/forlinx_cmd_demo/fltest_watchdog$ make CC=aarch64-linux-gcc
aarch64-linux-gnu-gcc fltest_watchdog.c -o fltest_watchdog
fltest_watchdog make finish!!!
