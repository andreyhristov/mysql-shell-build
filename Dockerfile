ARG UBUNTU_VERSION=20.10
FROM ubuntu:${UBUNTU_VERSION} AS protobuf_builder
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential zlib1g-dev \
    autoconf automake libtool curl make g++ unzip \
    libgtest-dev \
    joe wget unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#ARG BAZEL_VERSION=4.0.0

#RUN wget https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel_$BAZEL_VERSION-linux-x86_64.deb \
#        && dpkg -i bazel_$BAZEL_VERSION-linux-x86_64.deb \
#        && rm bazel_$BAZEL_VERSION-linux-x86_64.deb

ARG PROTOBUF_VERSION=3.11.4
RUN mkdir /protobuf
WORKDIR /protobuf
RUN wget https://github.com/protocolbuffers/protobuf/archive/v$PROTOBUF_VERSION.tar.gz && tar zxvf *.tar.gz
# maybe we need to run make check to run the tests?
RUN cd protobuf-$PROTOBUF_VERSION && ./autogen.sh && ./configure && make -j`nproc` && make install

FROM ubuntu:${UBUNTU_VERSION} as mysql_server_builder
ARG UBUNTU_VERSION
ARG MYSQL_VERSION=8.0.23

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential bison libssl-dev libprotobuf-c-dev cmake libcurl4-openssl-dev  \
    joe git wget lsb-release libncurses-dev pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    

RUN wget https://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.debhttps://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.deb \
    && DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config*.deb \
    && rm *.deb \
    && apt update \
    && apt install mysql-router-community mysql-shell mysql-community-client mysql-community-client-plugins libmysqlclient-dev -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-boost-$MYSQL_VERSION.tar.gz \
    && tar zxvf mysql-boost-$MYSQL_VERSION.tar.gz \
    && rm mysql-boost-$MYSQL_VERSION.tar.gz \
    && mkdir /mysql-$MYSQL_VERSION-build \
    && cmake -S /mysql-$MYSQL_VERSION \
             -B /mysql-$MYSQL_VERSION-build/ \
             -DWITH_SSL:STRING=system \
             -DMYSQL_MAINTAINER_MODE:BOOL=ON \
             -DWITH_DEBUG:BOOL=ON \
             -DWITH_BOOST=/mysql-$MYSQL_VERSION/boost/boost_1_73_0/ \
    && cd /mysql-$MYSQL_VERSION-build \
    && make -j`nproc`

FROM ubuntu:${UBUNTU_VERSION} as mysql_shell_builder
ARG UBUNTU_VERSION
ARG MYSQL_VERSION=8.0.23
   
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential libssl-dev libprotobuf-c-dev cmake python3-dev python3-protobuf libcurl4-openssl-dev \
    nodejs \
    joe git wget lsb-release libncurses-dev pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=protobuf_builder /usr/local/ /usr/local/
RUN echo "/usr/local/lib" >> /etc/ld.so.conf.d/local && ldconfig

COPY --from=mysql_server_builder /mysql-$MYSQL_VERSION-build /mysql-$MYSQL_VERSION-build
COPY --from=mysql_server_builder /mysql-$MYSQL_VERSION /mysql-$MYSQL_VERSION

WORKDIR /
RUN wget https://dev.mysql.com/get/Downloads/MySQL-Shell/mysql-shell-$MYSQL_VERSION-src.tar.gz \
    && tar zxvf mysql-shell-$MYSQL_VERSION-src.tar.gz \
    && rm mysql-shell-$MYSQL_VERSION-src.tar.gz \
    && mkdir /mysql-shell-build \
    && cmake -S /mysql-shell-$MYSQL_VERSION-src \
             -B /mysql-shell-build \
             -DCMAKE_INSTALL_PREFIX:PATH=/usr/local-mysqlsh \
             -DMYSQL_SOURCE_DIR=/mysql-$MYSQL_VERSION \
             -DMYSQL_BUILD_DIR=/mysql-$MYSQL_VERSION-build/ \
             -DWITH_PROTOBUF=/usr/local -DHAVE_PYTHON=1 \
    && cd /mysql-shell-build \
    && make -j`nproc` \
    && make install

FROM ubuntu:${UBUNTU_VERSION}
ARG UBUNTU_VERSION
ARG MYSQL_VERSION

WORKDIR /
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-pip curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# MySQL Shell needs `certifi`
RUN pip3 install certifi
COPY --from=protobuf_builder /usr/local/lib/libprotobuf.so* /usr/lib/
COPY --from=mysql_shell_builder /usr/local-mysqlsh /usr/
