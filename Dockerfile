# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/unrar:latest as unrar

FROM ghcr.io/linuxserver/baseimage-alpine:3.21

ARG BUILD_DATE
ARG TAG=4.1.0-beta.1
ARG VERSION=$TAG
ARG TRANSMISSION_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="machsix"

# Note: This rebuilds the web UI to avoid issues such as https://github.com/transmission/transmission/issues/6632
# Note: This downgrades GTKMM4 as it's outdated on alpine https://pkgs.alpinelinux.org/package/edge/community/x86/gtkmm4
# Note: This deletes .git to build as release not debug build

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    clang \
    cmake \
    curl-dev \
    dbus-glib-dev \
    git \
    gtkmm4-dev \
    libdeflate-dev \
    libevent-dev \
    libpsl-dev \
    llvm \
    miniupnpc-dev \
    npm \
    openssl-dev \
    qt6-qtsvg-dev \
    qt6-qttools-dev \
    samurai && \
  echo "**** install packages ****" && \
  apk add --no-cache \
    findutils \
    libdeflate \
    libevent \
    miniupnpc \
    p7zip \
    python3 && \
  echo "**** compile transmission ****" && \
  mkdir -p /tmp/transmission && \
  git clone https://github.com/transmission/transmission.git /tmp/transmission && \
  cd /tmp/transmission && \
  git checkout $TAG && \
  git submodule init && \
  git submodule update && \
  rm -rf .git && \
  sed -i -e 's/set(GTKMM4_MINIMUM 4.11.1)/set(GTKMM4_MINIMUM 4.10.0)/g' CMakeLists.txt && \
  sed -i -e 's/^set(TR_VERSION_MAJOR.*/set(TR_VERSION_MAJOR "4")/' CMakeLists.txt && \
  sed -i -e 's/^set(TR_VERSION_MINOR.*/set(TR_VERSION_MINOR "0")/' CMakeLists.txt && \
  sed -i -e 's/^set(TR_VERSION_PATCH.*/set(TR_VERSION_PATCH "0")/' CMakeLists.txt && \
  sed -i -e 's/^set(TR_VERSION_BETA_NUMBER.*/set(TR_VERSION_BETA_NUMBER "")/' CMakeLists.txt && \
  sed -i -e 's/^set(TR_VERSION_DEV TRUE)/set(TR_VERSION_DEV FALSE)/' CMakeLists.txt && \
  npm --prefix web ci && \
  npm --prefix web run build && \
  echo "**** build ****" && \
  CC=clang \
	CXX=clang++ \
	CXXFLAGS="$CXXFLAGS -flto -O2 -DNDEBUG" \
	CFLAGS="$CFLAGS -flto -O2 -DNDEBUG" \
	cmake -B build -G Ninja \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_INSTALL_LIBDIR=lib \
		-DCMAKE_BUILD_TYPE=None \
		-DBUILD_SHARED_LIBS=OFF \
		-DDISABLE_DEPRECATED=OFF \
		-DENABLE_CLI=ON \
		-DENABLE_GTK=OFF \
		-DENABLE_NLS=ON \
		-DENABLE_QT=OFF \
		-DENABLE_TESTS="$(want_check && echo ON || echo OFF)" \
		-DINSTALL_LIB=OFF \
		-DRUN_CLANG_TIDY=OFF \
		-DUSE_GTK_VERSION=4 \
		-DUSE_QT_VERSION=6 \
		-DUSE_SYSTEM_DEFLATE=ON \
		-DUSE_SYSTEM_EVENT2=ON \
		-DUSE_SYSTEM_MINIUPNPC=ON \
		-DUSE_SYSTEM_PSL=ON \
		-DWITH_CRYPTO="openssl" \
		-DWITH_SYSTEMD=OFF && \
	cmake --build build && \
  echo "**** manuall run pre-instal  from aports ****" && \
  curl -o "/tmp/transmission-daemon.pre-install" "https://git.alpinelinux.org/aports/plain/community/transmission/transmission-daemon.pre-install" && \
  chmod +x /tmp/transmission-daemon.pre-install && /tmp/transmission-daemon.pre-install && \
  echo "**** install transmission ****" && \
  cmake --install build && \
  mkdir -p /etc/conf.d/ && \
  mkdir -p /etc/init.d/ && \
  echo "**** manually copy config from aports ****" && \
  curl -o "/etc/conf.d/transmission-daemon" "https://git.alpinelinux.org/aports/plain/community/transmission/transmission-daemon.confd" && \
  curl -o "/etc/init.d/transmission-daemon" "https://git.alpinelinux.org/aports/plain/community/transmission/transmission-daemon.initd" && \
  chmod +x /etc/init.d/transmission-daemon && \
  curl -o "/etc/logrotate.d/transmission-daemon" "https://git.alpinelinux.org/aports/plain/community/transmission/transmission-daemon.logrotate" && \
  curl -o "/tmp/transmission-daemon.post-upgrade" "https://git.alpinelinux.org/aports/plain/community/transmission/transmission-daemon.post-upgrade" && \
  chmod +x /tmp/transmission-daemon.post-upgrade && /tmp/transmission-daemon.post-upgrade && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    $HOME/.cache

# copy local files
COPY root/ /

# add unrar
COPY --from=unrar /usr/bin/unrar-alpine /usr/bin/unrar

# ports and volumes
EXPOSE 9091 51413/tcp 51413/udp
VOLUME /config
