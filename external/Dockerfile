FROM httpd

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano tshark iproute2 iptables pkg-config tcpdump nmap wget curl openssl hping3 openvpn

WORKDIR /

RUN mkdir -p /run/sshd

RUN echo "root:root" | chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config

COPY ./index_ext1.html/ /usr/local/apache2/htdocs/index.html

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /usr/local/apache2/conf/server.key \
    -out /usr/local/apache2/conf/server.crt \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=10.5.0.20"

COPY ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf

RUN echo "LoadModule ssl_module modules/mod_ssl.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/httpd-ssl.conf" >> /usr/local/apache2/conf/httpd.conf

COPY ./client.conf /etc/openvpn/client.conf
COPY ./ca.crt /etc/openvpn/keys/ca.crt
COPY ./client.crt /etc/openvpn/keys/client.crt
COPY ./client.key /etc/openvpn/keys/client.key

EXPOSE 22 443

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
