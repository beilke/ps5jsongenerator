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

# Copy cron configuration
COPY cronjobs /etc/cron.d/cronjobs
RUN chmod 0644 /etc/cron.d/cronjobs && \
    crontab /etc/cron.d/cronjobs

# Create log file
RUN touch /var/log/cron.log

# Startup script with 30-minute delay
RUN echo -e '#!/bin/sh\n\
echo "Container started, waiting 30 minutes for first run..."\n\
sleep 1800\n\
echo "Starting cron in foreground..."\n\
crond -l 2 -f' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]