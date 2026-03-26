FROM ubuntu:24.04

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano tshark iproute2 iptables pkg-config tcpdump nmap

WORKDIR /

RUN mkdir -p /run/sshd

RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config

EXPOSE 22

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
