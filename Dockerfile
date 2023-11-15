ARG NGINX_VERSION=1.25.3
FROM nginx:${NGINX_VERSION} as builder
ARG TARGETARCH
ARG PSOL=jammy
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
        apt-get update && apt-get install -y \
        wget \
        tar \
        build-essential \
        xz-utils \
        git \
        build-essential \
        zlib1g-dev \
        libpcre3 \
        libpcre3-dev \
        unzip uuid-dev && \
    mkdir -p /opt/build-stage
WORKDIR /opt/build-stage
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz

# AMD64 아키텍처
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    wget http://www.tiredofit.nl/psol-${PSOL}.tar.xz && \
    git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git && \
    tar xvf psol-${PSOL}.tar.xz && \
    mv psol incubator-pagespeed-ngx && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz; \
    fi

# ARM64 아키텍처
ARG ARCH=arm64
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    wget https://gitlab.com/gusco/ngx_pagespeed_arm/-/raw/master/psol-1.15.0.0-aarch64.tar.gz && \
    git clone --depth=1 https://github.com/apache/incubator-pagespeed-ngx.git && \
    tar xvf psol-1.15.0.0-aarch64.tar.gz && \
    mv psol incubator-pagespeed-ngx && \
    sed -i 's/x86_64/aarch64/' incubator-pagespeed-ngx/config && \
    sed -i 's/x64/aarch64/' incubator-pagespeed-ngx/config && \
    sed -i 's/-luuid/-l:libuuid.so.1/' incubator-pagespeed-ngx/config && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz; \
    fi

WORKDIR nginx-${NGINX_VERSION}
RUN ./configure --with-compat --add-dynamic-module=../incubator-pagespeed-ngx && \
    make modules

FROM nginx:${NGINX_VERSION} as final
COPY --from=builder /opt/build-stage/nginx-${NGINX_VERSION}/objs/ngx_pagespeed.so /usr/lib/nginx/modules/
COPY nginx.conf /etc/nginx/nginx.conf