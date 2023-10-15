FROM debian:12 as build

ARG GIT_COMMIT="v0.27.0"
ARG BOOST_VERSION="1_83_0"

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends ca-certificates wget git build-essential cmake libasound2-dev libpulse-dev libvorbisidec-dev libvorbis-dev libopus-dev libflac-dev libsoxr-dev alsa-utils libavahi-client-dev avahi-daemon libexpat1-dev

WORKDIR /boost
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_${BOOST_VERSION}.tar.gz -O boost.tar.gz \
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

FROM rust:1-bookworm as build-librespot

ARG GIT_COMMIT="v0.4.2"

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends ca-certificates git build-essential pkg-config libasound2-dev

WORKDIR /librespot
RUN git clone https://github.com/librespot-org/librespot.git \
    && cd librespot \
    && git checkout ${GIT_COMMIT}

RUN cd librespot \
    && cargo build --release --no-default-features --features "alsa-backend"

FROM debian:12
WORKDIR /app

RUN apt-get update && apt-get upgrade -y --no-install-recommends
RUN apt-get install -y --no-install-recommends libasound2-dev libpulse-dev libvorbisidec-dev libvorbis-dev libopus-dev libflac-dev libsoxr-dev alsa-utils libavahi-client-dev avahi-daemon libexpat1-dev

COPY --from=build /app/snapcast/bin/* /app/
COPY --from=build-librespot /librespot/librespot/target/release/librespot /app/

ENTRYPOINT /app/snapserver
#CMD avahi-daemon --daemonize --no-drop-root &; /app/snapserver
EXPOSE 1704/tcp 1705/tcp 1780
