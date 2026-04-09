#!/bin/sh
set -e

WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
# 仅清理工作目录，不清理系统目录，因为默认用户每次使用新的容器进行构建（仓库中的构建指南是这么指导的）
rm -rf *.tar.gz \
    *.tar \
    deps \
    zsh-5.9 \
    zsh-5.9-ohos-arm64

# 下载一些命令行工具，并将它们软链接到 bin 目录中
cd /opt
echo "coreutils 9.10
busybox 1.37.0
grep 3.12
gawk 5.3.2
make 4.4.1
tar 1.35
gzip 1.14" >/tmp/tools.txt
while read -r name ver; do
    curl -fLO https://github.com/Harmonybrew/ohos-$name/releases/download/$ver/$name-$ver-ohos-arm64.tar.gz
done </tmp/tools.txt
ls | grep tar.gz$ | xargs -n 1 tar -zxf
rm -rf *.tar.gz
ln -sf $(pwd)/*-ohos-arm64/bin/* /bin/

# 准备 ohos-sdk
curl -fL -o ohos-sdk-full_6.1-Release.tar.gz https://cidownload.openharmony.cn/version/Master_Version/OpenHarmony_6.1.0.31/20260311_020435/version-Master_Version-OpenHarmony_6.1.0.31-20260311_020435-ohos-sdk-full_6.1-Release.tar.gz
tar -zxf ohos-sdk-full_6.1-Release.tar.gz
rm -rf ohos-sdk-full_6.1-Release.tar.gz ohos-sdk/windows ohos-sdk/linux
cd ohos-sdk/ohos
busybox unzip -q native-*.zip
busybox unzip -q toolchains-*.zip
rm -rf *.zip
cd $WORKDIR

# 把 llvm 里面的命令封装一份放到 /bin 目录下，只封装必要的工具。
# 为了照顾 clang （clang 软链接到其他目录使用会找不到 sysroot），
# 对所有命令统一用这种封装的方案，而非软链接。
essential_tools="clang
clang++
clang-cpp
ld.lld
lldb
llvm-addr2line
llvm-ar
llvm-cxxfilt
llvm-nm
llvm-objcopy
llvm-objdump
llvm-ranlib
llvm-readelf
llvm-size
llvm-strings
llvm-strip"
for executable in $essential_tools; do
    cat <<EOF > /bin/$executable
#!/bin/sh
exec /opt/ohos-sdk/ohos/native/llvm/bin/$executable "\$@"
EOF
    chmod 0755 /bin/$executable
done

# 把 llvm 软链接成 cc、gcc 等命令
cd /bin
ln -s clang cc
ln -s clang gcc
ln -s clang++ c++
ln -s clang++ g++
ln -s ld.lld ld
ln -s llvm-addr2line addr2line
ln -s llvm-ar ar
ln -s llvm-cxxfilt c++filt
ln -s llvm-nm nm
ln -s llvm-objcopy objcopy
ln -s llvm-objdump objdump
ln -s llvm-ranlib ranlib
ln -s llvm-readelf readelf
ln -s llvm-size size
ln -s llvm-strip strip

ZSH_PREFIX="/opt/zsh-5.9-ohos-arm64"
mkdir $WORKDIR/deps
cd $WORKDIR/deps

# 编译 ncurses
curl -fLO https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz
tar -zxf ncurses-6.5.tar.gz
cd ncurses-6.5
./configure \
    --prefix=/opt/deps \
    --enable-termcap \
    --enable-widec \
    --without-shared \
    --with-terminfo-dirs=$ZSH_PREFIX/share/terminfo:/data/zsh-5.9-ohos-arm64/share/terminfo \
    --with-fallbacks=xterm,xterm-256color,xterm-color,screen,screen-256color,tmux,tmux-256color,linux,vt100,vt102,ansi
make -j$(nproc)
make install
cd ..

cd $WORKDIR

# 编译 zsh
export CPPFLAGS="-I/opt/deps/include"
export LDFLAGS="-L/opt/deps/lib"
curl -fLO https://sourceforge.net/projects/zsh/files/zsh/5.9/zsh-5.9.tar.xz
busybox xz -d zsh-5.9.tar.xz
tar -xf zsh-5.9.tar
cd zsh-5.9
./configure \
    --host=aarch64-linux \
    --prefix=$ZSH_PREFIX \
    --disable-dynamic \
    --enable-multibyte \
    --with-tcsetpgrp
sed -i 's@^name=zsh/regex .*link=no@name=zsh/regex modfile=Src/Modules/regex.mdd link=static auto=yes load=no@' config.modules
make -j$(nproc)
make install
cd ..

# 将 terminfo 数据库携带到制品中
cp -r /opt/deps/share/terminfo $ZSH_PREFIX/share/

# 进行代码签名
cd /opt/zsh-5.9-ohos-arm64
find . -type f \( -perm -0111 -o -name "*.so*" \) | while read FILE; do
    if file -b "$FILE" | grep -iqE "elf|sharedlib|ELF|shared object"; then
        echo "Signing binary file $FILE"
        ORIG_PERM=$(stat -c %a "$FILE")
        /opt/ohos-sdk/ohos/toolchains/lib/binary-sign-tool sign -inFile "$FILE" -outFile "$FILE" -selfSign 1
        chmod "$ORIG_PERM" "$FILE"
    fi
done
cd $WORKDIR

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
cat <<EOF > $ZSH_PREFIX/licenses.txt
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

zsh
=============
$(cat zsh-5.9/LICENCE)

ncurses
=============
==license==
$(cat deps/ncurses-6.5/COPYING)
==authors==
$(cat deps/ncurses-6.5/AUTHORS)
EOF

# 打包最终产物
cp -r $ZSH_PREFIX ./
tar -zcf zsh-5.9-ohos-arm64.tar.gz zsh-5.9-ohos-arm64

# 这一步是针对手动构建场景做优化。
# 在 docker run --rm -it 的用法下，有可能文件还没落盘，容器就已经退出并被删除，从而导致压缩文件损坏。
# 使用 sync 命令强制让文件落盘，可以避免那种情况的发生。
sync
