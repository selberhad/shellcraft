FROM alpine:3.20 AS builder

# Install Rust toolchain and build dependencies
RUN apk add --no-cache \
    cargo \
    rust \
    musl-dev

# Copy Rust workspace (build context is repo root)
COPY rust-bins /build/rust-bins
WORKDIR /build/rust-bins

# Build all binaries in release mode (fully statically linked)
# Set RUSTFLAGS to statically link libgcc and use musl
ENV RUSTFLAGS="-C target-feature=+crt-static"
RUN cargo build --release

# Runtime stage
FROM alpine:3.20

# Install Perl, cron, and essential GNU tools
RUN apk add --no-cache \
    perl \
    dcron \
    coreutils \
    grep \
    sed \
    gawk \
    findutils \
    ncurses \
    bash

# Create non-root player user
RUN adduser -D -h /home -s /usr/local/bin/shellcraft.pl player

# Create game world directories
RUN mkdir -p \
    /sewer \
    /crypt \
    /tower \
    /etc/scrolls \
    /usr/local/lib/shellcraft

# Copy Rust binaries from builder
COPY --from=builder /build/rust-bins/target/release/quest /home/quest

# Copy game shell, dungeon master, and libraries (build context is repo root)
COPY docker/game-image/shellcraft.pl /usr/local/bin/shellcraft.pl
COPY docker/game-image/dungeon-master.pl /usr/sbin/dungeon-master
COPY docker/game-image/lib/ShellCraft/ /usr/local/lib/shellcraft/
COPY docker/game-image/init/populate-world.sh /tmp/populate-world.sh

# Make shell and binaries executable, populate world
RUN chmod +x /usr/local/bin/shellcraft.pl && \
    chmod +x /usr/sbin/dungeon-master && \
    chmod 700 /usr/sbin/dungeon-master && \
    chmod +x /home/quest && \
    chmod +x /tmp/populate-world.sh && \
    /tmp/populate-world.sh && \
    rm /tmp/populate-world.sh && \
    chown -R player:player /home
    # Note: /sewer, /crypt, /tower permissions set by populate-world.sh

# Set up root crontab for Dungeon Master (runs every minute)
RUN echo "* * * * * /usr/sbin/dungeon-master >/dev/null 2>&1" | crontab -

# Set Perl library path
ENV PERL5LIB=/usr/local/lib/shellcraft

# Remove forbidden commands for security
# Keep basic shell but remove editors and network tools
RUN rm -f \
    /usr/bin/vi \
    /usr/bin/vim \
    /usr/bin/nano \
    /usr/bin/wget \
    /usr/bin/curl \
    /usr/bin/ssh \
    /usr/bin/scp \
    /usr/bin/python* \
    /usr/bin/ruby \
    /usr/bin/node \
    /usr/bin/npm

# Set working directory
WORKDIR /home

# Create entrypoint script that starts cron and switches to player user
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'crond' >> /entrypoint.sh && \
    echo 'exec su - player' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Run entrypoint (starts cron as root, then drops to player)
CMD ["/entrypoint.sh"]
