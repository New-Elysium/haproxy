#!/bin/sh
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Build QuicTLS
build_quictls() {
    log "Starting QuicTLS build for ARMv7"
    git clone -b OpenSSL_1_1_1t+quic https://github.com/quictls/openssl.git
    cd openssl
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
        no-dsa
    make -j$(nproc)
    make install_sw
    cd ..
    log "QuicTLS build completed"
}

# Build HAProxy
build_haproxy() {
    log "Starting HAProxy build for ARMv7"
    git clone https://github.com/haproxy/haproxy.git
    cd haproxy
    make -j$(nproc) TARGET=linux-glibc \
        USE_LUA=1 \
        USE_OPENSSL=1 \
        USE_PCRE=1 \
        USE_ZLIB=1 \
        USE_QUIC=1 \
        USE_PROMEX=1 \
        SSL_INC=/opt/quictls/include \
        SSL_LIB=/opt/quictls/lib \
        LDFLAGS="-Wl,-rpath,/opt/quictls/lib" \
        ADDLIB="-latomic" \
        EXTRA_OBJS="contrib/prometheus-exporter/service-prometheus.o" \
        CFLAGS="-O2" \
        VERBOSE=1
    make install-bin
    cd ..
    log "HAProxy build completed"
}

# Main build process
main() {
    log "Starting build process for ARMv7"
    build_quictls
    build_haproxy
    log "Build process completed"
}

# Run the main function
main
