# syntax=docker/dockerfile:1
FROM debian AS asterisk_initial
EXPOSE 5060

# Set a default environment variable, and allow an argument to override it
ARG ASTERISK_VERSION
ENV ASTERISK_VERSION=${ASTERISK_VERSION:-23.5.0}

# Volume for fail2ban jail
ENV FAIL2BANDATA=/var/lib/fail2ban  
VOLUME ["$FAIL2BANDATA"]

# Run asterisk under its own user to avoid escalation security issues
RUN useradd asteriskuser
RUN usermod asteriskuser -a -G asteriskuser

# Install prerequisites
RUN apt-get update &&\
    apt-get install -y bison &&\
    apt-get install -y flex &&\
    apt-get install -y subversion &&\
    apt-get install -y wget

# Download asterisk
WORKDIR /usr/local/src 
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz &&\
    tar -xvzf asterisk-${ASTERISK_VERSION}.tar.gz &&\
    rm *.tar.gz

# Install asterisk
WORKDIR /usr/local/src/asterisk-${ASTERISK_VERSION}
RUN contrib/scripts/get_mp3_source.sh &&\
    contrib/scripts/install_prereq install &&\
    ./configure &&\
    make menuselect.makeopts &&\
    menuselect/menuselect\
    --enable-category MENUSELECT_ADDONS\
    --enable-category MENUSELECT_AGIS\
    --enable-category MENUSELECT_FORMATS\
    menuselect.makeopts &&\
    make -j 3 &&\
    make install &&\
    make samples &&\
    make config &&\
    make install-logrotate &&\
    rm -rf ./*

FROM asterisk_initial AS asterisk_with_sounds
WORKDIR /usr/local/src

# Download announcement sounds
RUN apt-get install -y ffmpeg unzip &&\
    wget https://github.com/jaboles/DVA5/archive/refs/heads/master.zip &&\
    unzip master.zip &&\
    rm master.zip &&\
    mkdir /var/lib/asterisk/sounds/en/nsw &&\
    mv DVA5-master/sounds/Sydney-Female/*.mp3 /var/lib/asterisk/sounds/en/nsw &&\
    rm -rf DVA5-master/ &&\
    chmod 0777 -R /var/lib/asterisk/sounds/en/nsw
COPY --chmod=0755 rename-sounds.sh .
RUN ./rename-sounds.sh

# Join sounds for Domestic and International Airport stops
WORKDIR /var/lib/asterisk/sounds/en/nsw
RUN ffmpeg -i "concat:Domestic.mp3|Airport.mp3" -acodec copy Domestic-Airport.mp3 &&\
    ffmpeg -i "concat:Domestic.mp3|Airport.f.mp3" -acodec copy Domestic-Airport.f.mp3 &&\
    ffmpeg -i "concat:International.mp3|Airport.mp3" -acodec copy International-Airport.mp3 &&\
    ffmpeg -i "concat:International.mp3|Airport.f.mp3" -acodec copy International-Airport.f.mp3

FROM asterisk_with_sounds AS asterisk_with_python
# Create a Python virtual environment
RUN apt-get install -y python3-full python3-pip &&\
    mkdir /usr/local/envs &&\
    python3 -m venv /usr/local/envs/venv &&\
    . /usr/local/envs/venv/bin/activate &&\
    /usr/local/envs/venv/bin/python3 -m pip install pyst2 requests tzdata

FROM asterisk_with_python AS asterisk_with_protobuf
# Download and compile the NSW GTFS Realtime Protobuf extension
RUN apt-get install -y protobuf-compiler &&\
    /usr/local/envs/venv/bin/python3 -m pip install --upgrade protobuf &&\
    wget https://opendata.transport.nsw.gov.au/data/dataset/868860ea-feb0-4602-adde-f6b4ba48d738/resource/9d9b1e2d-598a-49b7-9920-d629dc968b72/download/gtfs-realtime_1007_extension.proto__0.txt &&\
    mv gtfs-realtime_1007_extension.proto__0.txt nsw-gtfs-realtime.proto &&\
    protoc --python_out=/var/lib/asterisk/agi-bin nsw-gtfs-realtime.proto &&\
    rm nsw-gtfs-realtime.proto

FROM asterisk_with_protobuf AS asterisk_final
# Install fail2ban
RUN apt-get install -y fail2ban iproute2 iptables
COPY --chmod=0755 fail2ban/jail.local /etc/fail2ban
RUN touch /var/log/asterisk/security &&\
    chown asteriskuser:asteriskuser /var/log/asterisk/security

# Modify permissions
RUN chown -R asteriskuser:asteriskuser /usr/lib/asterisk /var/*/asterisk /usr/sbin/asterisk /etc/asterisk /var/lib/asterisk/agi-bin /usr/local/envs &&\
    chmod -R 0777 /usr/lib/asterisk /var/*/asterisk /usr/sbin/asterisk /etc/asterisk /var/lib/asterisk/agi-bin /usr/local/envs

# Copy configuration and Python AGI script
COPY config /etc/asterisk
COPY --chown=asteriskuser:asteriskuser --chmod=0755 announcement.py /var/lib/asterisk/agi-bin

FROM asterisk_final AS asterisk_deploy
USER root
WORKDIR /
COPY --chown=root:root entrypoint.sh /
RUN apt-get install -y sudo
ENTRYPOINT ["bash", "entrypoint.sh"]