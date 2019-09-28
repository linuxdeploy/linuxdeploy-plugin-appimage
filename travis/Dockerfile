FROM centos:6

SHELL ["/bin/bash", "-x", "-c"]

RUN yum install -y centos-release-scl-rh && \
    yum install -y devtoolset-7 wget curl patchelf vim-common fuse libfuse2 libtool autoconf automake zlib-devel libjpeg-devel libpng-devel nano git && \
    wget https://github.com/Kitware/CMake/releases/download/v3.13.4/cmake-3.13.4-Linux-x86_64.tar.gz -O- | tar xz --strip-components=1 -C/usr/local

ENV ARCH=x86_64
COPY entrypoint.sh /
SHELL ["/entrypoint.sh", "bash", "-x", "-c"]
ENTRYPOINT ["/entrypoint.sh"]
