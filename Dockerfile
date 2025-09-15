FROM debian:12 as build-snapcast

ARG GIT_COMMIT="v0.32.3"
ARG BOOST_VERSION_1="1.89.0"
ARG BOOST_VERSION_2="1_89_0"

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends ca-certificates wget git build-essential cmake cmake-format ccache ninja-build alsa-utils avahi-daemon libasound2-dev libavahi-client-dev libboost-dev libexpat1-dev libflac-dev libjack-dev libopus-dev libpulse-dev libsoxr-dev libssl-dev libvorbis-dev libvorbisidec-dev

WORKDIR /boost
RUN wget https://archives.boost.io/release/${BOOST_VERSION_1}/source/boost_${BOOST_VERSION_2}.tar.gz -O boost.tar.gz \
    && tar xf ./boost.tar.gz \
    && rm ./boost.tar.gz \
    && mv ./boost* ./boost

WORKDIR /app

RUN git clone https://github.com/badaix/snapcast.git \
    && cd snapcast \
    && git checkout ${GIT_COMMIT}

RUN cd snapcast \
    && mkdir build \
    && cd build \
    && cmake .. -DBUILD_SERVER=ON -DBUILD_CLIENT=OFF -DBUILD_WITH_PULSE=OFF -DBOOST_ROOT=/boost/boost \
    && cmake --build .

FROM node as build-snapweb
ARG GIT_COMMIT="react"

RUN apt-get update && apt-get upgrade -y --no-install-recommends

WORKDIR /app

RUN git clone https://github.com/badaix/snapweb.git \
    && cd snapweb \
    && git checkout ${GIT_COMMIT}

RUN cd snapweb \
    && npm ci \
    && npm run build

FROM rust:1-bookworm as build-librespot

ARG GIT_COMMIT="v0.7.1"

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends ca-certificates git build-essential pkg-config libasound2-dev

WORKDIR /librespot
RUN git clone https://github.com/librespot-org/librespot.git \
    && cd librespot \
    && git checkout ${GIT_COMMIT}

RUN cd librespot \
    && cargo build --release --no-default-features --features "alsa-backend native-tls with-libmdns"

FROM debian:12 as build-shairport

ARG GIT_COMMIT="4.3.7"

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends ca-certificates git build-essential autoconf automake libtool libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev

WORKDIR /shairport

RUN git clone https://github.com/mikebrady/shairport-sync.git \
    && cd shairport-sync \
    && git checkout ${GIT_COMMIT}

RUN cd shairport-sync \
    && autoreconf -fi \
    && ./configure --sysconfdir=/etc --with-ssl=openssl --with-metadata --with-stdout --with-pipe --with-avahi \
    && make \
    && make install


FROM debian:12
WORKDIR /app

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends  \
    ca-certificates \
    procps \
    libasound2-dev  \
    libpulse-dev  \
    libvorbisidec-dev  \
    libvorbis-dev  \
    libopus-dev  \
    libflac-dev  \
    libsoxr-dev  \
    alsa-utils  \
    libavahi-client-dev  \
    avahi-daemon  \
    libnss-mdns \
    libexpat1-dev \
    libtool  \
    libpopt-dev  \
    libconfig-dev  \
    libssl-dev \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad


COPY --from=build-snapcast /app/snapcast/bin/* /app/
COPY --from=build-snapweb /app/snapweb/build /app/snapweb
COPY --from=build-librespot /librespot/librespot/target/release/librespot /app/
COPY --from=build-shairport /shairport/shairport-sync/shairport-sync /app/
COPY avahi.conf /etc/avahi/avahi-daemon.conf
CMD mkdir -p /run/dbus
COPY run.sh /app/run.sh

#ENTRYPOINT /app/snapserver
CMD /app/run.sh
#CMD avahi-daemon --daemonize --no-drop-root && /app/snapserver
EXPOSE 1704/tcp 1705/tcp 1780
