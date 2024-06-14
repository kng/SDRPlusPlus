ARG DEBIAN_IMAGE_TAG=bookworm
FROM debian:${DEBIAN_IMAGE_TAG} AS builder

ARG DEBIAN_FRONTEND=noninteractive 
ARG CMAKE_BUILD_PARALLEL_LEVEL
ENV TZ=Etc/UTC

COPY packages.builder /usr/src/
RUN apt -y update && \
    apt -y upgrade && \
    xargs -a /usr/src/packages.builder apt install --no-install-recommends -qy

# install everything in /target and it will go in to / on destination image. symlink make it easier for builds to find files installed by this.
RUN mkdir -p /target/usr && rm -rf /usr/local && ln -sf /target/usr /usr/local

# Install SDRPlay libraries
RUN curl --no-keepalive -o SDRplay_RSP_API-Linux-3.15.1.run https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-3.15.1.run &&\
    7z x ./SDRplay_RSP_API-Linux-3.15.1.run &&\
    7z x ./SDRplay_RSP_API-Linux-3.15.1 &&\
    mkdir -p /target/usr/bin /target/usr/lib /target/usr/include &&\
    cp x86_64/sdrplay_apiService /target/usr/bin/ &&\
    chmod 0755 /target/usr/bin/sdrplay_apiService &&\
    cp x86_64/libsdrplay_api.so.3.15 /target/usr/lib/libsdrplay_api.so &&\
    cp inc/* /target/usr/include/ &&\
    ldconfig

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
          -DCMAKE_STAGING_PREFIX=/target/usr/local \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_BUILD_TYPE=Release \
          -DOPT_BUILD_BLADERF_SOURCE=ON \
          -DOPT_BUILD_LIMESDR_SOURCE=ON \
          -DOPT_BUILD_SDRPLAY_SOURCE=ON \
          -DOPT_BUILD_NEW_PORTAUDIO_SINK=ON \
          -DOPT_BUILD_M17_DECODER=ON \
          -DOPT_BUILD_PERSEUS_SOURCE=ON && \
    cmake --build build --target install # -- -j$(nproc)

ARG DEBIAN_IMAGE_TAG=bookworm
FROM debian:${DEBIAN_IMAGE_TAG} AS runner

ARG DEBIAN_FRONTEND=noninteractive

COPY packages.runner /usr/src/
RUN apt -y update && \
    apt -y upgrade && \
    xargs -a /usr/src/packages.runner apt install -qy && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /target /
COPY root /opt/sdrpp
RUN ldconfig
RUN printf "#!/bin/bash\nsdrplay_apiService &\nsdrpp -r /opt/sdrpp -s\n" > /usr/bin/start.sh &&\
    chmod 0755 /usr/bin/start.sh
CMD ["start.sh"]
