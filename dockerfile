# Use a specific Alpine version for stability
FROM alpine:3.20

# Install dependencies with correct package names
RUN apk add --no-cache \
    bash \
    jq \
    docker-cli \
    findutils \
    coreutils \
    sed \
    grep \
    gawk \
    curl

# Install OpenOrbis toolchain
RUN mkdir -p /lib/OpenOrbisSDK/bin/linux && \
    curl -L https://example.com/path/to/PkgTool.Core -o /lib/OpenOrbisSDK/bin/linux/PkgTool.Core && \
    chmod +x /lib/OpenOrbisSDK/bin/linux/PkgTool.Core

WORKDIR /app

# Copy script
COPY jsonGenerator.sh /app/jsonGenerator.sh
RUN chmod +x /app/jsonGenerator.sh

# Run the script once and exit
CMD ["/app/jsonGenerator.sh"]