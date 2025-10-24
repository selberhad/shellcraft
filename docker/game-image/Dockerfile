FROM alpine:3.19

# Install Perl and essential GNU tools
RUN apk add --no-cache \
    perl \
    coreutils \
    grep \
    sed \
    gawk \
    findutils \
    ncurses \
    bash

# Create game world directories
RUN mkdir -p \
    /home \
    /sewer \
    /crypt \
    /tower \
    /etc/scrolls \
    /usr/local/lib/shellcraft

# Copy game shell and libraries
COPY shellcraft.pl /usr/local/bin/shellcraft.pl
COPY lib/ShellCraft/ /usr/local/lib/shellcraft/
COPY init/welcome.txt /etc/shellcraft/welcome.txt
COPY init/populate-world.sh /tmp/populate-world.sh

# Make shell executable
RUN chmod +x /usr/local/bin/shellcraft.pl && \
    chmod +x /tmp/populate-world.sh && \
    /tmp/populate-world.sh && \
    rm /tmp/populate-world.sh

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

# Run game shell as entrypoint
CMD ["perl", "/usr/local/bin/shellcraft.pl"]
