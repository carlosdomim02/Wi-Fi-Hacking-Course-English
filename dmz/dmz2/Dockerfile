FROM httpd

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano iproute2 iptables pkg-config tcpdump nmap wget openssl fail2ban syslog-ng libpam-google-authenticator

WORKDIR /

RUN mkdir -p /run/sshd

# ssh hardering config
COPY sshd_config /etc/ssh/sshd_config

RUN useradd -m -s /bin/bash "carlos" && \
    echo "carlos:passw0rd1234" | chpasswd && \
    mkdir /home/carlos/.ssh && \
    mkdir -p /run/sshd

COPY .ssh/id_rsa.pub /home/carlos/.ssh/authorized_keys
RUN chmod 600 /home/carlos/.ssh/authorized_keys && \
    chown -R carlos:carlos /home/carlos/.ssh
    
# Custom init SSH banner
COPY banner.sh /ssh/banner.sh
RUN chmod +x /ssh/banner.sh && \
    echo "source /ssh/banner.sh" >> /home/carlos/.bashrc

# Auth tries limit
COPY jail.local /etc/fail2ban/jail.local

# Double auth factor config
#COPY google_authenticator /home/carlos/.google_authenticator
#RUN chown carlos:carlos /home/carlos/.google_authenticator && \
#    chmod 600 /home/carlos/.google_authenticator && \
#    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd

# http/https config
COPY ./index_dmz2.html/ /usr/local/apache2/htdocs/index.html

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /usr/local/apache2/conf/server.key \
    -out /usr/local/apache2/conf/server.crt \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=10.5.1.21"

COPY ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf

RUN echo "LoadModule ssl_module modules/mod_ssl.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/httpd-ssl.conf" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 2222 443

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
