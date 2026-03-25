FROM debian:bookworm-slim AS builder
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install git libnl-3-dev libnl-genl-3-dev libssl-dev gcc libpcsclite-dev \
                    make libc6-dev libsqlite3-dev pkg-config libnl-route-3-dev \
                    libdbus-1-dev libreadline-dev -y --no-install-recommends && \
    apt-get autoclean && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*
RUN git clone --depth 1 --branch hostap_2_11 git://w1.fi/hostap.git && cp hostap wpa_supplicant -R

# wpa_supplicant
WORKDIR /wpa_supplicant/wpa_supplicant/
COPY ./wpa_supplicant-config.conf .config
RUN make

##########################################################################################

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install libnl-3-200 libnl-genl-3-200 libnl-route-3-200 libdbus-1-3 \
                    libssl-dev libsqlite3-0 pcscd libreadline8 iptables isc-dhcp-client \
                    openssh-server net-tools iputils-ping traceroute nano iproute2 curl \
                    pkg-config wget arping arp-scan telnet namp -y --no-install-recommends && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*

# Setup SSH conections
WORKDIR /
RUN mkdir -p /run/sshd
RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config
EXPOSE 22

# Setup hostapd and wpa_supplicant
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_passphrase /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_cli /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_supplicant /usr/local/bin/

# Setup running files
WORKDIR /client
COPY ./wpa_supplicant_wlan1.conf .
COPY ./wpa_supplicant_wlan2.conf .

# Start services
COPY ./start.sh .
RUN chmod +x start.sh
CMD ["/usr/sbin/sshd", "-D"]
