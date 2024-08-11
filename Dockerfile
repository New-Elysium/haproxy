# Build stage
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    g++ \
    git \
    libc-dev \
    linux-headers \
    lua5.3-dev \
    make \
    pcre-dev \
    perl \
    tar \
    zlib-dev

# Build QuicTLS with limited ciphers, Use v3.3 OpenSSL when available
WORKDIR /build
RUN git clone --depth 1 -b OpenSSL_1_1_1t+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./Configure no-shared \
    --prefix=/opt/quictls \
    linux-armv4 \
    no-weak-ssl-ciphers \
    no-ssl3 \
    no-dtls \
    no-bf \
    no-cast \
    no-md2 \
    no-md4 \
    no-ripemd \
    no-camellia \
    no-idea \
    no-seed \
    no-rc2 \
    no-rc4 \
    no-rc5 \
    no-dsa \
    enable-ec_nistp_64_gcc_128 && \
    make -j$(nproc) && \
    make install_sw

# Build HAProxy with optimized options
WORKDIR /build
RUN git clone --depth 1 https://github.com/haproxy/haproxy.git && \
    cd haproxy && \
    make -j$(nproc) TARGET=linux-glibc \
    USE_LUA=1 \
    USE_OPENSSL=1 \
    USE_PCRE=1 \
    USE_ZLIB=1 \
    USE_QUIC=1 \
    USE_PROMEX=1 \
    USE_SYSTEMD=1 \
    SSL_INC=/opt/quictls/include \
    SSL_LIB=/opt/quictls/lib \
    LDFLAGS="-Wl,-rpath,/opt/quictls/lib" \
    ADDLIB="-latomic" \
    EXTRA_OBJS="contrib/prometheus-exporter/service-prometheus.o" \
    CFLAGS="-O2 -march=armv7-a" \
    LIBS_FLAGS="-static-libgcc -static-libstdc++" && \
    make install-bin

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    lua5.3-libs \
    pcre \
    zlib \
    ca-certificates

# Copy built artifacts from builder stage
COPY --from=builder /usr/local/sbin/haproxy /usr/local/sbin/haproxy
COPY --from=builder /opt/quictls /opt/quictls

# Set up HAProxy
RUN addgroup -S haproxy && adduser -S -G haproxy haproxy && \
    mkdir -p /etc/haproxy /var/lib/haproxy && \
    touch /etc/haproxy/haproxy.cfg && \
    chown -R haproxy:haproxy /etc/haproxy /var/lib/haproxy

USER haproxy

EXPOSE 80 443

CMD ["haproxy", "-f", "/etc/haproxy/haproxy.cfg"]
