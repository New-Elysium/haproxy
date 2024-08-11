# Build stage
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
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

# Build QuicTLS, Use OpenSSL_3_3t+quic when stable
WORKDIR /build
RUN git clone https://github.com/quictls/openssl.git && \
    cd openssl && \
    git checkout OpenSSL_1_1_1t+quic && \
    ./Configure no-shared --prefix=/opt/quictls linux-armv4 && \
    make -j$(nproc) && \
    make install_sw

# Build HAProxy
WORKDIR /build
RUN git clone https://github.com/haproxy/haproxy.git && \
    cd haproxy && \
    make TARGET=linux-glibc \
    USE_LUA=1 \
    USE_OPENSSL=1 \
    USE_PCRE=1 \
    USE_ZLIB=1 \
    USE_QUIC=1 \
    SSL_INC=/opt/quictls/include \
    SSL_LIB=/opt/quictls/lib \
    LDFLAGS="-Wl,-rpath,/opt/quictls/lib" \
    ADDLIB="-latomic" && \
    make install-bin

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    lua5.3-libs \
    pcre \
    zlib \
    ca-certificates \
    && addgroup -S haproxy && adduser -S -G haproxy haproxy

# Copy built artifacts from builder stage
COPY --from=builder /usr/local/sbin/haproxy /usr/local/sbin/haproxy
COPY --from=builder /opt/quictls /opt/quictls

# Set up HAProxy
RUN mkdir -p /etc/haproxy /var/lib/haproxy && \
    touch /etc/haproxy/haproxy.cfg

# Switch to non-root user
USER haproxy

EXPOSE 80 443 8404

CMD ["haproxy", "-f", "/etc/haproxy/haproxy.cfg"]
