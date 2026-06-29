Forlinx Desktop系统是飞凌在ubuntu base的基础上构建的桌面操作系统，完全兼容ubuntu22.04，支持apt-get等，相对传统的Linux系统易用性更高。

本章节主要描述开发板相关源码的编译方法，包括内核源码编译、应用程序编译方法。

## <font style="color:#000000;">4.1编译前准备</font>
### <font style="color:#000000;">4.1.1 环境说明</font>
+ 开发环境操作系统：Ubuntu22.04  64位版
+ 交叉工具链：aarch64-linux-gnu
+ 开发板使用Bootloader 版本：u-boot-2017.09
+ 开发板内核版本：linux-5.10.160
+ 开发板移植QT版本：qt5.15.3

### <font style="color:#000000;">4.1.2 拷贝源码 </font>
🛤️ 程序源码：用户资料\Linux\源码\OK3568-linux-source.tar.bz2

创建工作目录

```markdown
forlinx@ubuntu:~$ mkdir -p /home/forlinx/3568						//按照顺序创建工作目录
将用户资料中的源码文件OK3568_Linux_fs.tar.bz2.0*拷贝到虚拟机/home/forlinx/3568目录。
forlinx@ubuntu:~$ cd /home/forlinx/3568									//切换到工作目录
forlinx@ubuntu:~/3568$ cat OK3568_Linux_fs.tar.bz2.0* > OK3568_Linux_fs.tar.bz2
forlinx@ubuntu:~/3568$ tar -xvf OK3568_Linux_fs.tar.bz2			//在当然位置解压压缩包
```

运行命令后等待完成即可。

## <font style="color:#000000;">4.2 源码编译</font>
⁉️ **注意：**

+ **初次解压内核源码后，需要先对源码进行整体编译**
+ **整体编译过后，可根据实际情况再进行单独编译**
+ **该源码编译需要开发环境运行内存8G及以上，请不要修改我们提供的VM虚拟机镜像配置**

### <font style="color:#000000;">4.2.1 全编译测试</font>
在源码路径内，提供了编译脚本build.sh，运行该脚本对整个源码进行编译，需要在终端切换到解压出来的源码路径，找到build.sh文件。

```markdown
forlinx@ubuntu:~$ cd /home/forlinx/3568/OK3568_Linux_fs
```

以下操作需要在源码目录下操作，选择编译配置：

```markdown
forlinx@ubuntu:~/3568/OK3568_Linux_fs$ ./build.sh defconfig
```

执行后会有选项输入，如下图，输入3后按回车继续。

<img src="https://cdn.nlark.com/yuque/0/2025/png/45471259/1743478942763-68265633-64e9-49f3-ac39-c6ff42aacd60.png" width="734" title="" crop="0,0,1,1" id="udb10dc68" class="ne-image">

完成上述配置后，使用命令进行全编译：

```markdown
forlinx@ubuntu:~/3568/OK3568_Linux_fs$ ./build.sh
```

<img src="https://cdn.nlark.com/yuque/0/2025/png/45471259/1743479316064-731d8384-6211-4515-b401-2d1d585dadc7.png" width="731" title="" crop="0,0,1,1" id="ub9e984e1" class="ne-image">

编译成功后，将在OK3568_Linux_fs/rockdev文件夹下生成对应编译工程结果文件，找到其中的镜像文件。

<img src="https://cdn.nlark.com/yuque/0/2025/png/50461850/1740967893085-6993301c-972a-4cb2-ac2d-64e43e932d7d.png" width="1169" title="null" crop="0,0,1,1" id="yoIyd" class="ne-image">

⁉️ **注意：**update.img为打包好用于OTG或者TF卡完全烧写用，其它文件为分步烧写使用

### <font style="color:#000000;">4.2.2 单独编译内核</font>
用户在内核源码路径下进行操作。 

```markdown
forlinx@ubuntu:~/3568/OK3568_Linux_fs$ ./build.sh kernel
```

<img src="https://cdn.nlark.com/yuque/0/2025/png/50461850/1740967893180-f35264b3-2934-481f-ba51-cea6b23f3581.png" width="881" title="null" crop="0,0,1,1" id="KMDUU" class="ne-image">

编译成功后update.img里的内核不更新。请分步烧写kerndl/boot.img文件。

### <font style="color:#000000;">4.2.3 清除编译生成的文件</font>
用户在内核源码路径下进行操作。

```markdown
forlinx@ubuntu:~/3568/OK3568_Linux_fs$ ./build.sh cleanall
```

<img src="https://cdn.nlark.com/yuque/0/2025/png/50461850/1740967893261-34870309-6fb4-4476-bda2-174341658293.png" width="1031" title="null" crop="0,0,1,1" id="zdGzN" class="ne-image">

该操作清除所有中间文件。但不影响源文件，包括已经有改动的源文件。

## <font style="color:#000000;">4.3 Image文件的使用</font>
update.img为打包好用于OTG或者TF卡完全烧写用，其它文件为分步烧写使用。单独编译生成的Image文件不会在update.img文件中更新，需使用单步烧写来烧录（详见软件手册OTG烧写）。
