FROM debian:bookworm-slim AS builder
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install git libnl-3-dev libnl-genl-3-dev libssl-dev gcc libpcsclite-dev \
                    make libc6-dev libsqlite3-dev pkg-config libnl-route-3-dev \
                    libdbus-1-dev libreadline-dev -y --no-install-recommends && \
    apt-get autoclean && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*
RUN git clone --depth 1 --branch hostap_2_11 git://w1.fi/hostap.git && cp hostap wpa_supplicant -R

# hostapd
WORKDIR /hostap/hostapd/
COPY ./hostapd-config.conf .config
RUN make

##########################################################################################

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install libnl-3-200 libnl-genl-3-200 libnl-route-3-200 libdbus-1-3 \
                    libssl-dev libsqlite3-0 pcscd libreadline8 isc-dhcp-server iptables \
                    openssh-server net-tools iputils-ping traceroute nano iproute2 \
                    pkg-config wget -y --no-install-recommends && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*

# Setup SSH conections
WORKDIR /
RUN mkdir -p /run/sshd
RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config
EXPOSE 22

# Setup hostapd and wpa_supplicant
COPY --from=builder /hostap/hostapd/hostapd /usr/local/bin/
COPY --from=builder /hostap/hostapd/hostapd_cli /usr/local/bin/

# Setup running files
WORKDIR /ap
# COPY ./hostapd-WPA.conf ./hostapd.conf
COPY ./hostapd-WPA2.conf ./hostapd.conf
COPY ./dhcp.conf /etc/dhcp/dhcpd.conf 

# Start services
COPY ./start.sh .
RUN chmod +x start.sh
CMD ["/usr/sbin/sshd", "-D"]