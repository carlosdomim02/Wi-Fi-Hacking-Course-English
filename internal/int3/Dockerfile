FROM ubuntu:24.04

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano tshark iproute2 iptables pkg-config tcpdump nmap wget openvpn easy-rsa

WORKDIR /

RUN mkdir -p /run/sshd

RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config

COPY ./server.conf /etc/openvpn/server.conf
COPY ./ca.crt /etc/openvpn/keys/ca.crt
COPY ./server.crt /etc/openvpn/keys/server.crt
COPY ./server.key /etc/openvpn/keys/server.key
COPY ./dh.pem /etc/openvpn/keys/dh2048.pem

EXPOSE 22
EXPOSE 1194/udp  

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
