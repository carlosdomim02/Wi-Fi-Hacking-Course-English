FROM kalilinux/kali-rolling AS builder
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install git libnl-3-dev libnl-genl-3-dev libssl-dev gcc libpcsclite-dev \
                    make libc6-dev libtalloc-dev libsqlite3-dev pkg-config libnl-route-3-dev \
                    libdbus-1-dev libreadline-dev ca-certificates -y --no-install-recommends && \
    apt-get autoclean && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*
RUN git clone --depth 1 --branch hostap_2_11 git://w1.fi/hostap.git && cp hostap wpa_supplicant -R

# wpa_supplicant
WORKDIR /wpa_supplicant/wpa_supplicant/
COPY ./wpa_supplicant-config.conf .config
RUN make

# hostapd
WORKDIR /hostap/hostapd/
COPY ./hostapd-config.conf .config
RUN make

# freeradius
WORKDIR /freeradius
COPY ./freeradius-server-3.2.7.tar.gz .
RUN tar -xzf freeradius-server-3.2.7.tar.gz 

WORKDIR /freeradius/freeradius-server-3.2.7
RUN ./configure && \
    make && \
    make install

##########################################################################################

FROM kalilinux/kali-rolling
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install libnl-3-200 libnl-genl-3-200 libnl-route-3-200 libdbus-1-3 arping hydra \
                    libssl-dev libsqlite3-0 pcscd libreadline8 kali-tools-wireless macchanger set \
                    iptables isc-dhcp-client openssh-server net-tools traceroute namp arp-scan ettercap-text-only \
                    nano iputils-ping pkg-config isc-dhcp-server metasploit-framework -y --no-install-recommends && \
    rm -rf /var/lib/dpkg/status-old /var/lib/apt/lists/*

# Setup SSH conections
WORKDIR /
RUN mkdir -p /run/sshd
RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config
EXPOSE 22

# Setup freeradius
COPY --from=builder /usr/local /usr/local

# Setup hostapd and wpa_supplicant
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_passphrase /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_cli /usr/local/bin/
COPY --from=builder /wpa_supplicant/wpa_supplicant/wpa_supplicant /usr/local/bin/
COPY --from=builder /hostap/hostapd/hostapd /usr/local/bin/
COPY --from=builder /hostap/hostapd/hostapd_cli /usr/local/bin/

# Setup running files
WORKDIR /attacker
COPY ./ssh_usernames.txt .
COPY ./ssh_passwords.txt .
COPY ./wpa_supplicant.conf .
COPY ./hostapd.conf .
COPY ./dhcp.conf /etc/dhcp/dhcpd.conf 
COPY ./clients.conf .
COPY ./eap .
COPY ./users .
COPY ./radius.conf .
# COPY ./clients.conf /etc/freeradius/clients.conf
# COPY ./eap /etc/freeradius/mods-available/eap
# COPY ./users /etc/freeradius/mods-config/files/authorize
# COPY ./radius.conf /etc/freeradius/radiusd.conf

# Start services
COPY ./start.sh .
RUN chmod +x start.sh
CMD ["/usr/sbin/sshd", "-D"]
