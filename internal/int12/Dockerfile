FROM ubuntu:24.04

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano telnet iproute2 iptables pkg-config tcpdump nmap wget

WORKDIR /

RUN mkdir -p /run/sshd

RUN echo "root:root" |chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config

COPY .ssh/ /.ssh/
RUN chmod 600 .ssh/id_rsa

EXPOSE 22

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
