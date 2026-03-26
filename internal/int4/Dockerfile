FROM vulnerables/cve-2014-6271

RUN echo "deb http://archive.debian.org/debian jessie main" > /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/99unauth

# Install some tools
RUN apt-get update && \
    apt-get install -y --allow-unauthenticated \
        net-tools iputils-ping wget curl nano openssh-server 
     
# SSH config
RUN mkdir -p /run/sshd && \
    echo "root:root" | chpasswd && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Setup check file
RUN echo "Enhorabuena!!! Has hackeado esta máquina." > /root/hacking-completed.txt

# Expose SSH y SMB (EternalBlue attack)
EXPOSE 22 445

COPY start.sh /start.sh
RUN chmod +x /start.sh
ENTRYPOINT ["/start.sh"]
