#!/bin/sh
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    *.tar.xz \
    ncurses-6.5 \
    zsh-5.9 \
    ohos-sdk \
    ncurses-6.5-ohos-arm64 \
    zsh-5.9-ohos-arm64

# 准备 ohos-sdk
mkdir ohos-sdk
curl -L -O https://repo.huaweicloud.com/openharmony/os/6.0-Release/ohos-sdk-windows_linux-public.tar.gz
tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ohos-sdk
cd ohos-sdk/linux
unzip -q native-*.zip
cd ../..

# 设置交叉编译所需的环境变量
export OHOS_SDK=${WORKDIR}/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-D__MUSL__=1"
export CXXFLAGS="-D__MUSL__=1"

# 编译 ncurses
curl -L -O https://mirrors.ustc.edu.cn/gnu/ncurses/ncurses-6.5.tar.gz
tar -zxf ncurses-6.5.tar.gz
cd ncurses-6.5
./configure \
    --host=aarch64-linux \
    --prefix=${WORKDIR}/ncurses-6.5-ohos-arm64 \
    --without-shared \
    --without-debug \
    --with-strip-program=$STRIP \
    --enable-termcap \
    --with-fallbacks=xterm,xterm-256color,xterm-color,screen,screen-256color,tmux,tmux-256color,linux,vt100,vt102,ansi
make -j$(nproc)
make install
cd ..

# 编译 zsh
curl -L -O https://sourceforge.net/projects/zsh/files/zsh/5.9/zsh-5.9.tar.xz
tar -xf zsh-5.9.tar.xz
cd zsh-5.9
./configure \
    --host=aarch64-linux \
    --prefix=${WORKDIR}/zsh-5.9-ohos-arm64 \
    --disable-dynamic \
    --with-ncurses=${WORKDIR}/ncurses-6.5-ohos-arm64 \
    CPPFLAGS="-I${WORKDIR}/ncurses-6.5-ohos-arm64/include" \
    LDFLAGS="-L${WORKDIR}/ncurses-6.5-ohos-arm64/lib"
sed -i 's@^name=zsh/regex .*link=no@name=zsh/regex modfile=Src/Modules/regex.mdd link=static auto=yes load=no@' config.modules
make -j$(nproc)
make install
cd ..

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
zsh_license=$(cat zsh-5.9/LICENCE; echo)
ncurses_license=$(cat ncurses-6.5/COPYING; echo)
ncurses_authors=$(cat ncurses-6.5/AUTHORS; echo)
printf '%s\n' "$(cat <<EOF
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

zsh
=============
$zsh_license

ncurses
=============
==license==
$ncurses_license
==authors==
$ncurses_authors
EOF
)" > zsh-5.9-ohos-arm64/licenses.txt

# 打包最终产物
tar -zcf zsh-5.9-ohos-arm64.tar.gz zsh-5.9-ohos-arm64
