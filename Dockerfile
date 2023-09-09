ARG DEBIAN_IMAGE_TAG=bookworm
FROM debian:${DEBIAN_IMAGE_TAG} AS builder

ARG DEBIAN_FRONTEND=noninteractive 

COPY packages.builder /usr/src/
RUN apt -y update && \
    apt -y upgrade && \
    xargs -a /usr/src/packages.builder apt install --no-install-recommends -qy

# Install SDRPlay libraries
#WORKDIR /usr/src/sdrplay
#RUN wget https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.07.1.run && \
#    7z x ./SDRplay_RSP_API-Linux-3.07.1.run && \
#    7z x ./SDRplay_RSP_API-Linux-3.07.1 && \
#    cp x86_64/libsdrplay_api.so.3.07 /usr/lib/libsdrplay_api.so && \
#    cp inc/* /usr/include/

WORKDIR /usr/src/libperseus-sdr
RUN git clone https://github.com/Microtelecom/libperseus-sdr.git . && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    ldconfig

WORKDIR /usr/src/sdrplusplus
COPY . .
RUN cmake -B build \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_BUILD_TYPE=Release \
          -DOPT_BUILD_BLADERF_SOURCE=ON \
          -DOPT_BUILD_LIMESDR_SOURCE=ON \
          -DOPT_BUILD_SDRPLAY_SOURCE=OFF \
          -DOPT_BUILD_NEW_PORTAUDIO_SINK=ON \
          -DOPT_BUILD_M17_DECODER=ON \
          -DOPT_BUILD_PERSEUS_SOURCE=ON && \
    cmake --build build --target install -- -j$(nproc)

ARG DEBIAN_IMAGE_TAG=bookworm
FROM debian:${DEBIAN_IMAGE_TAG} AS runner

ARG DEBIAN_FRONTEND=noninteractive

COPY packages.runner /usr/src/
RUN apt -y update && \
    apt -y upgrade && \
    xargs -a /usr/src/packages.runner apt install -qy && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local /usr/local
COPY root /opt/sdrpp
RUN ldconfig
CMD ["sdrpp","-r","/opt/sdrpp","-s"]

