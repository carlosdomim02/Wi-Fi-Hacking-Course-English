FROM httpd

RUN apt-get update && apt-get install -y openssh-server net-tools iputils-ping traceroute nano iproute2 iptables pkg-config tcpdump nmap wget openssl git python3-venv libssl-dev libffi-dev build-essential libpython3-dev python3-minimal authbind

# http/https server config
RUN mkdir -p /run/sshd

RUN echo "root:root" | chpasswd
RUN sed -ri "s/^#?PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config

COPY ./index_dmz1.html/ /usr/local/apache2/htdocs/index.html

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /usr/local/apache2/conf/server.key \
    -out /usr/local/apache2/conf/server.crt \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=10.5.1.20"

COPY ssl.conf /usr/local/apache2/conf/extra/httpd-ssl.conf

RUN echo "LoadModule ssl_module modules/mod_ssl.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/httpd-ssl.conf" >> /usr/local/apache2/conf/httpd.conf

# Cowrie config
#RUN adduser --disabled-password --gecos "" cowrie 
RUN adduser --disabled-password cowrie 

USER cowrie
WORKDIR /home/cowrie

RUN git clone https://github.com/cowrie/cowrie.git
WORKDIR /home/cowrie/cowrie

RUN python3 -m venv cowrie-env && \
    /bin/bash -c "source cowrie-env/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

RUN cp /home/cowrie/cowrie/etc/userdb.example /home/cowrie/cowrie/etc/userdb.txt && \
    sed -ri "s/^#?hostname\s+.*/hostname = carlos/" /home/cowrie/cowrie/etc/cowrie.cfg.dist && \
    echo "carlos:x:1234" >> /home/cowrie/cowrie/etc/userdb.txt && \
    sed -i '/^\[telnet\]/,/^\[.*\]/ s/^enabled = false/enabled = true/' etc/cowrie.cfg.dist

USER root

EXPOSE 22 2222 443

COPY ./start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
