FROM ubuntu:14.04 AS builder
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install git libnl-3-dev libnl-genl-3-dev libssl-dev gcc libpcsclite-dev \
                    make libc6-dev libsqlite3-dev pkg-config libnl-route-3-dev \
                    libdbus-1-dev libncurses5-dev libreadline-dev -y --no-install-recommends && \
    apt-get autoclean && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*
RUN git clone --depth 1 --branch hostap_2_6 git://w1.fi/hostap.git && cp hostap wpa_supplicant -R

# wpa_supplicant
WORKDIR /wpa_supplicant/wpa_supplicant/
COPY ./wpa_supplicant-config.conf .config
RUN make

##########################################################################################

FROM kirscht/metasploitable3-ub1404
# Solo usamos repos confiables que aún están accesibles
RUN apt-get install -y --no-install-recommends --allow-unauthenticated nmap \
        libnl-3-200 libnl-genl-3-200 libnl-route-3-200 libdbus-1-3 arping curl wget \
        libncurses5-dev libssl-dev libsqlite3-0 pcscd libreadline6 arp-scan telnet \
        && rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*

# Expose SSH, but not modify it
EXPOSE 22

# Setup hostapd and wpa_supplicant
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_passphrase /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_cli /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_supplicant /usr/local/bin/

# Setup running files
WORKDIR /client
COPY ./wpa_supplicant.conf .

# Setup check file
RUN echo "Enhorabuena!!! Has hackeado esta máquina." > /root/hacking-completed.txt

# Start services
COPY ./start.sh .
RUN chmod +x start.sh
CMD ["/usr/sbin/sshd", "-D"]