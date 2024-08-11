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
    zlib-dev \
    openssl-dev \
    curl

# Copy build script
COPY build.sh /build/build.sh
RUN chmod +x /build/build.sh

# Run build script
WORKDIR /build
RUN ./build.sh

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    lua5.3-libs \
    pcre \
    zlib \
    libatomic \
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
