FROM debian:jessie

ENV PATH="$PATH:/build/tools/bin" CCPREFIX="/build/tools/bin/arm-linux-gnueabihf-" BUILD_ARCH=arm-linux-gnueabihf BUILD_PREFIX=/opt/ffmpeg
RUN apt-get update && \
    apt-get install -y \
        git-core \
        nano \
        autoconf \
        automake \
        binutils \
        bison \
        build-essential \
        curl \
        flex \
        gawk \
        gperf \
        libncurses5-dev \
        libtool \
        libtool-bin \
        texinfo \
        tmux \
        unzip \
        yasm \
        help2man

WORKDIR /build
RUN git clone --depth=1 https://github.com/raspberrypi/tools raspain && \
    mv raspain/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64 tools && \
    rm -rfR raspain

# build lib AAC plus
RUN curl -s http://tipok.org.ua/downloads/media/aac+/libaacplus/libaacplus-2.0.2.tar.gz | tar -zx -C /usr/src
WORKDIR /usr/src/libaacplus-2.0.2
RUN ./autogen.sh --with-parameter-expansion-string-replace-capable-shell=/bin/bash --host=${BUILD_ARCH} --enable-static --prefix=${BUILD_PREFIX}
RUN make && make install

# build ALSA
RUN curl -s ftp://ftp.alsa-project.org/pub/lib/alsa-lib-1.1.0.tar.bz2 | tar -jx -C /usr/src
WORKDIR /usr/src/alsa-lib-1.1.0
RUN ./configure --host=${BUILD_ARCH} --prefix=${BUILD_PREFIX}
RUN make -j6 && make install

# build x264
RUN git clone --depth=1 git://git.videolan.org/x264 /usr/src/x264
WORKDIR /usr/src/x264
RUN ./configure --host=${BUILD_ARCH} --enable-static --cross-prefix=${CCPREFIX} --prefix=${BUILD_PREFIX} --extra-cflags='-march=armv7-a -mfpu=neon-vfpv4' --extra-ldflags='-march=armv7-a'
RUN make -j6 && make install

# build LAME mp3
RUN curl -Ls "http://downloads.sourceforge.net/project/lame/lame/3.99/lame-3.99.5.tar.gz" | tar -zx -C /usr/src
WORKDIR /usr/src/lame-3.99.5
RUN CC=${CCPREFIX}gcc CFLAGS="-march=armv7-a -mfpu=neon-vfpv4" ./configure --host=${BUILD_ARCH} --enable-static --prefix=${BUILD_PREFIX}
RUN make -j6 && make install

# build ffmpeg
RUN git clone --depth=1 git://source.ffmpeg.org/ffmpeg.git /usr/src/ffmpeg
WORKDIR /usr/src/ffmpeg
RUN PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig ./configure --enable-cross-compile --cross-prefix=${CCPREFIX} --arch=armhf --target-os=linux --prefix=${BUILD_PREFIX} --enable-gpl --enable-libx264 --enable-nonfree --enable-libaacplus --enable-libmp3lame --extra-cflags="-I${BUILD_PREFIX}/include" --extra-ldflags="-L${BUILD_PREFIX}/lib" --enable-static --pkg-config-flags="--static" --extra-libs=-ldl
RUN make -j6 && make install
RUN make distclean

WORKDIR /opt/ffmpeg