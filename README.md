# ohos-zsh
本项目为 OpenHarmony 平台编译了 zsh，并发布预构建包。

## 获取软件包
前往 [release 页面](https://github.com/Harmonybrew/ohos-zsh/releases) 获取。

## 用法
**1\. 在鸿蒙 PC 中使用**

鸿蒙 PC 内置了 zsh，系统自带的“终端”（HiShell）里面默认的 shell 就是 zsh，用户不需要再另装一个 zsh。

**2\. 在鸿蒙开发板中使用**

用 hdc 把它推到设备上，然后以“解压 + 配 PATH” 的方式使用。

示例：
```sh
hdc file send zsh-5.9-ohos-arm64.tar.gz /data
hdc shell

cd /data
tar -zxf zsh-5.9-ohos-arm64.tar.gz
export PATH=$PATH:/data/zsh-5.9-ohos-arm64/bin

# 现在你可以使用 zsh 命令了
```

除了配 PATH 使用，你也可以直接把 zsh 这个文件复制到 /bin 目录下使用（开发板上需要先执行 `mount -o remount,rw /` 命令把根目录挂载为读写）。这个 zsh 把除 libc 以外的依赖都静态链接了，可单文件使用。

**3\. 在 [鸿蒙容器](https://github.com/hqzing/docker-mini-openharmony) 中使用**

在容器中用 curl 下载这个软件包，然后以“解压 + 配 PATH” 的方式使用。

示例：
```sh
docker run -itd --name=ohos ghcr.io/hqzing/docker-mini-openharmony:latest
docker exec -it ohos sh

cd /root
curl -L -O https://github.com/Harmonybrew/ohos-zsh/releases/download/5.9/zsh-5.9-ohos-arm64.tar.gz
tar -zxf zsh-5.9-ohos-arm64.tar.gz -C /opt
export PATH=$PATH:/opt/zsh-5.9-ohos-arm64/bin

# 现在你可以使用 zsh 命令了
```

除了配 PATH 使用，你也可以直接把 zsh 这个文件复制到 /bin 目录下使用。这个 zsh 把除 libc 以外的依赖都静态链接了，可单文件使用。

## 从源码构建

**1\. 手动构建**

需要用一台 Linux x64 服务器来运行项目里的 build.sh，以实现 zsh 的交叉编译。

这里以 Ubuntu 24.04 x64 作为示例：
```sh
sudo apt update && sudo apt install -y build-essential unzip
./build.sh
```

**2\. 使用流水线构建**

如果你熟悉 GitHub Actions，你可以直接复用项目内的工作流配置，使用 GitHub 的流水线来完成构建。

这种情况下，你使用的是 GitHub 提供的构建机，不需要自己准备构建环境。

只需要这么做，你就可以进行你的个人构建：
1. Fork 本项目，生成个人仓
2. 在个人仓的“Actions”菜单里面启用工作流
3. 在个人仓提交代码或发版本，触发流水线运行

## 常见问题

**1\. 键盘按键异常**

如果这个 zsh 在你的设备上不能正常运行（如键盘按键异常等），可以尝试先设置 TERM 这个环境变量，再启动它。

```sh
export TERM=screen-256color
zsh
```

这个 zsh 内置了一些常用的 terminfo：xterm,xterm-256color,xterm-color,screen,screen-256color,tmux,tmux-256color,linux,vt100,vt102,ansi

请结合你自己所使用的终端环境情况，从这个列表里面选一个适合你的值作为你的 TERM 环境变量值。

如果这里的值也不能满足，可以提 issue 求助。
