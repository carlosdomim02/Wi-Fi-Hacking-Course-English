# Lab Configuration

Throughout this section (branch), a detailed explanation will be provided of how the lab was created and of its particular features. This includes both the composition of the general configuration files—such as [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/docker-compose.yml), [`launch.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/launch.sh), and [`stop.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/stop.sh)—as well as each of the files that make up the different machines described in the [introduction](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English). However, all the technologies used must first be understood.

## Technologies Used

The following explains details that should be taken into account in order to understand the real operation of the lab, from the tools used to simulate the environment to some services of interest for connecting or protecting the various components of that environment.

### Docker

Docker is an open-source tool managed by Docker Inc., whose main goal is to package applications and deploy them easily both in local environments and in the cloud [[1](https://learn.microsoft.com/es-es/dotnet/architecture/microservices/container-docker-introduction/docker-defined)]. This technology is based on the execution of containers, which are standardized and executable components that combine the code of the application to be packaged together with all its dependencies (both operating system dependencies and those of other technologies). This means that applications run through these containers only include the minimum necessary for execution, making them highly portable (they can run in almost any environment) and efficient [[2](https://www.ibm.com/es-es/think/topics/docker)].

Containers are possible thanks to certain Linux kernel capabilities that allow processes to run in isolation with the help of namespaces. These wrap a global system resource (such as a filesystem mount, a network interface, a hostname, etc.) in an abstraction that makes processes inside that namespace believe they have their own isolated instance of the global resource, even becoming invisible to the rest of the processes outside that namespace. Thus, `/proc/<PID>/ns/` indicates the namespaces of which a process is a member, while `/var/run/netns/` represents a directory where network interface namespaces are stored, making it possible for them to be moved to a specific process [[3](https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/what-namespaces-are-setting-limits-for-applications)].

All of this makes it possible to achieve lightweight virtualization that allows applications to run with only the necessary dependencies, thus gaining a major advantage over traditional virtual machines (VMs), which involve greater overhead because full systems must be installed and run. More specifically, the advantages over traditional VMs are the following [[2](https://www.ibm.com/es-es/think/topics/docker)]:

- **Lower weight:** Docker containers only carry the minimum host technology required, together with the indispensable dependencies. In addition, they do not need a complete virtual machine or a hypervisor acting as an intermediary between the container and the host system. Docker Engine is enough: a technology with a function similar to a hypervisor, but far lighter, since it acts as a daemon process. The execution of the container itself is represented as just another process on the host machine, without requiring a full virtual machine.
- **Greater portability and productivity:** Unlike VMs, containers start from an image that is written once and can easily be distributed across different systems, being independent of the environment in which they run.
- **Greater efficiency and scalability:** Especially in cloud systems, containerization tends to be used to run multiple instances of the same application quickly, thanks to the faster startup/shutdown speed of containers and the reduced use of resources.

![image](https://github.com/user-attachments/assets/02ccb8b7-62d4-4470-bce2-d64be76bc97f)

Due to all these advantages over VMs, this technology was chosen to create the lab used by the course. In this way, it becomes easy to create a series of customized "mini virtual machines" to simulate the network of a small company or a household. Since it is a lightweight and efficient form of virtualization, the lab allows for a greater number of machines and broad customization.

To better understand how containers work, the well-known concept of images must first be understood. A container is an image in execution: the image is the template used by Docker Engine to execute the instructions necessary to launch a container. Docker images store dependencies together with the code of the application or applications they run.

Docker is not the only containerization technology, although it is the most popular. Other options such as LXC (native Linux kernel containers) are more cumbersome to use. In contrast, Docker makes it easier to create, distribute, and version images (Docker Hub-style repositories). Docker relies on the Linux kernel, but it can run on Windows or macOS thanks to Docker Desktop, which uses lightweight virtualization (WSL 2) to provide the necessary kernel features [[5](https://docs.docker.com/desktop/setup/install/windows-install/)].

#### Dockerfile

Docker makes it easier to create images through specifications stored in Dockerfiles, one of the most popular options. Dockerfiles are text files containing the instructions necessary for Docker Engine to build images through `docker build` [[6](https://docs.docker.com/build/concepts/dockerfile/)].

Normally these files start from an existing image (to take advantage of a minimal base) and then execute a series of instructions that allow customization. Finally, they specify a default command that is executed when the container is launched. In this way, Docker Engine creates a Docker image by applying the instructions on top of the base image, and the result is a read-only file used by `docker run` to launch the container.

```dockerfile
# Example Dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# install app dependencies
RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip install flask==3.0.*

# install app
COPY hello.py /

# final configuration
ENV FLASK_APP=hello
EXPOSE 8000
CMD ["flask", "run", "--host", "0.0.0.0", "--port", "8000"]
```

#### Docker-compose

In multi-container environments—where several Docker images are meant to be launched—managing the different containers can become complicated. For this reason, there is a tool that facilitates the building (`docker-compose build`) and execution (`docker-compose up`) of environments composed of multiple Docker containers, making tasks such as launching networks, services, or using shared volumes (directories and/or files) between the host and the container straightforward. All of this is achieved through the specification of a `YAML` configuration file (commonly `docker-compose.yml`), where the different services to be launched and the images they are based on are indicated, together with configuration options such as the networks they join or the order in which they are launched—respecting dependencies. In this way, simpler and more efficient administration of the running services is achieved [[7](https://docs.docker.com/compose/intro/compose-application-model/)].

```yaml
# Example docker-compose.yml
services:
  frontend:
    image: example/webapp
    ports:
      - "443:8043"
    networks:
      - front-tier
      - back-tier
    configs:
      - httpd-config
    secrets:
      - server-certificate

  backend:
    image: example/database
    volumes:
      - db-data:/etc/data
    networks:
      - back-tier

volumes:
  db-data:
    driver: flocker
    driver_opts:
      size: "10GiB"

configs:
  httpd-config:
    external: true

secrets:
  server-certificate:
    external: true

networks:
  # The presence of these objects is sufficient to define them
  front-tier: {}
  back-tier: {}
```

Because of all these advantages, it is a technology widely used in applications with microservices architecture. However, the environment represented by the lab built to train WiFi attack skills also benefits from these advantages by following an architecture that can be compared to microservices [[8](https://anderfernandez.com/blog/tutorial-docker-compose/)]. Multiple machines communicate with each other to accomplish a common task: the execution of a testing environment. In this way, these containers present a certain degree of isolation by only being able to communicate with each other according to what is specified between the Dockerfiles that build the images and the `docker-compose.yml` file that launches the environment, allowing control over the degree of communication of the different containers involved. In addition, it is possible to connect individually to each of the machines simulated in the environment (`docker-compose exec`), which makes it easier to adopt the perspective of an attacker who initially only knows their own machine.

### Firewall
![image](https://github.com/user-attachments/assets/587b710e-e50f-49fa-b4ff-c19867ca9cdb)

When building the lab, the goal was to obtain a realistic infrastructure that, although not offering the highest possible level of security, reflects a level high enough to resemble the real world. For that reason, one of the best-known and most effective security measures was implemented: a firewall. This is a device—hardware or software—capable of filtering packets with the main objective of preventing illegitimate access; however, it must also facilitate and manage communication between trusted devices. The main threats it attempts to avoid are the following [[9](https://www.incibe.es/ciudadania/tematicas/configuraciones-dispositivos/cortafuegos)]:
- Unauthorized access: they prevent traffic from untrusted sources.
- Malware propagation: they detect malicious traffic that may carry malware, blocking it to avoid spread.
- Denial of Service (DoS): they can detect massive data flows and block them.
- Protection against known vulnerabilities: they recognize malicious traffic attempting to exploit vulnerabilities.

There are different types of firewalls depending on the system to be protected [[10](https://www.paloaltonetworks.com/cyberpedia/types-of-firewalls)]:
- **Network firewalls:** placed at the boundary between networks—they separate trusted networks from untrusted ones—and apply traffic rules. Their main goal is to monitor, control, and decide which traffic is approved (or not) to pass into the trusted network. Normally, this type of firewall works through rules that indicate which traffic is allowed or not, and may also include other functionalities such as packet logging.  
  ![image](https://github.com/user-attachments/assets/7c71fbc6-9a77-4804-9ad4-b0a1fac6dcba)
- **Host-based firewalls:** software installed on the device to be protected, filtering only that machine's traffic (incoming, outgoing, or passing through it). It focuses on detecting malicious content, malicious software, or other malicious activities intended to infiltrate the protected system. They can be especially interesting in combination with the previously mentioned perimeter firewalls, since they offer a second layer of protection on individual devices in addition to that already offered by the network itself (through its perimeter firewall).  
  ![image](https://github.com/user-attachments/assets/45a7375f-c505-4dc7-877a-caaa076a4527)

For this lab, a network firewall is mainly used to limit traffic between the trusted network (internal and server networks) and the external network. On some hosts, an individual software firewall is used to add functionalities—for example, allowing specific traffic while still maintaining a certain degree of control so that only legitimate traffic is allowed. In addition, other classifications of these devices can be considered, such as the technology used to achieve their objective. In this case, the focus is placed on the only one used during the lab: packet filtering.

![image](https://github.com/user-attachments/assets/085d9818-2e40-452d-afb4-a7eec41b6d06)

As its name indicates, packet filtering regulates traffic between networks thanks to predefined rules that express patterns to accept or reject. These rules may declare attributes such as IP addresses (source/destination), ports, or protocols used by the transmitted packets in order to define which traffic is allowed through and which is not. Although the most common approach is to define static rules, there are mechanisms for creating or destroying rules dynamically—adapting rules in real time according to the context and current traffic. In addition, it is important to consider whether it is *stateless* (analyzes packets individually) or *stateful* (takes previous connections into account) [[10](https://www.paloaltonetworks.com/cyberpedia/types-of-firewalls)]. For this lab, a static stateless firewall was chosen (in most cases, although there is some stateful rule that acts on the response to a request), since that is enough to create a realistic DMZ structure.

#### DMZ
To build a realistic environment, one that can resemble that of a real company, a DMZ or demilitarized zone was created. This is an isolated network within the organization's internal network where only those devices offering services accessible from the Internet are located (for example, a web or mail server). This partition usually implies a higher level of protection on the internal network than on the server network—the latter must be accessible from the outside. Normally, the internal network seeks a high level of protection, preventing any incoming traffic that does not come from a connection initiated by a device inside that network. In addition, traffic between the networks (internal, DMZ, and external) is monitored and controlled by a firewall [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)].
![image](https://github.com/user-attachments/assets/e9aafaab-6ce4-40c8-9158-4f68a9e5e2ee)

This firewall is responsible for controlling traffic between the networks described above, in such a way that it normally restricts the internal network more heavily (not allowing connections to be initiated from outside it, whether from the external network or from the DMZ) than the network that hosts the servers accessible from the Internet (normally also accessible from the internal network, but not the other way around). This separation exists because servers accessible from the Internet are more likely to suffer attacks that could compromise their security. Thus, even if a cybercriminal were to compromise a server in the DMZ, it would still be difficult to access the local network thanks to filtering [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)].
![image](https://github.com/user-attachments/assets/93909e2c-d185-4ee1-a7aa-faeb89981bfb)
![image](https://github.com/user-attachments/assets/7fb9e819-baf3-4fe5-803b-c381a661c970)

On the other hand, there is another way to build this type of structure: using a double firewall, so that one first firewall (the one in direct contact with the external network and the DMZ) is responsible for establishing the rules that protect the DMZ (less restrictive), while a second one (which is connected to the first and to the internal network) establishes more restrictive rules to protect the internal network [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)]. This type of configuration can provide a more robust and modular structure; however, in the lab a single firewall was chosen because the structure is not very large, and one such device is sufficient.
![image](https://github.com/user-attachments/assets/28e804c6-5b6a-439d-89e8-3f8200d17a8d)

#### iptables
A typical and flexible way to integrate firewall rules into machines running the Linux kernel is to use `iptables`. This tool bases its operation on Netfilter—a powerful Linux kernel networking subsystem—which provides capabilities for packet filtering (stateful and stateless), as well as other services such as NAT or IP masking. In this way, `iptables` acts as a control interface over Netfilter, making it possible to create or destroy firewall rules using Shell commands [[12](https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/6/html/security_guide/sect-security_guide-firewalls#sect-Security_Guide-Firewalls-Netfilter_and_IPTables)].

### Honeypot
To continue with the idea of creating a realistic lab that implements countermeasures, a honeypot was installed on one of the DMZ servers. Normally, this tool monitors or detects cyberattacks in order to learn from them and avoid their future impact. In this way, honeypots are usually the first to detect attack attempts—they are also considered part of intrusion detection systems, or IDSs—without exposing information or other critical systems, although they usually imitate them as much as possible without revealing crucial details [[13](https://www.incibe.es/empresas/blog/honeypot-una-trampa-para-los-ciberdelincuentes)].

To deceive cybercriminals, a honeypot creates fake services that are likely to be attacked (web server, database) and records the method used by the attacker to carry out malicious actions. This allows the cybersecurity team to understand techniques and patterns, as well as create effective countermeasures—in addition to preventing the attack from being directed at the protected system if the cybercriminals fall into the honeypot trap [[13](https://www.incibe.es/empresas/blog/honeypot-una-trampa-para-los-ciberdelincuentes)].

There are several types of honeypots depending on the level of interaction they offer to the attacker. The higher this level of interaction, the more realistic they are, and the more effectively they can deceive cybercriminals [[14](https://pmc.ncbi.nlm.nih.gov/articles/PMC8036602/?sec1-sensors-21-02433)]:
- **Low interaction:** it does not provide real services, but rather simulates some basic ones, offering quick and easy installation and configuration. However, it is limited in terms of obtaining relevant data, since it only records simple details such as the date and time of the attack, the IPs involved, and ports.
- **Medium interaction:** they emulate services with a higher level of detail, and may even be capable of responding to attackers. These devices can be used to capture malware and/or simulate known vulnerabilities, but they are subject to greater risk by allowing more interaction from attackers, so a bad configuration may compromise the real system. In contrast, they usually offer a good balance between risk and the level of detail in the information they gather.
- **High interaction:** based on the use of real systems (fully vulnerable machines usually located inside the organization's internal network) that imitate real production environments. This option can gather the most information and offers great flexibility for attacker actions; however, this advantage is usually tied to high risk (a vulnerable machine is being created inside the internal network).

For this lab, a **medium-interaction** honeypot was chosen, since it does not require as many resources as a high-interaction honeypot and offers sufficient credibility to understand how these systems work.

#### Cowrie
To implement a honeypot in the lab, the tool known as Cowrie was chosen. It offers a fake SSH and Telnet service, mainly designed to log brute-force attacks. It supports two operating modes depending on the desired level of interaction: shell mode, which emulates a UNIX system through Python, and high-interaction mode, or Proxy mode, which uses real SSH and Telnet services and can even handle them from servers emulated with QEMU [[15](https://docs.cowrie.org/en/latest/README.html#what-is-cowrie)].

In shell mode, Cowrie can create a Debian 5.0-based filesystem with full capabilities such as adding or deleting files. In addition, it allows content to be added to files in order to deceive the attacker—for example, filling `/etc/passwd` with realistic-looking content. It is also capable of storing files that an attacker downloads with `wget`, `curl`, or protocols such as SFTP or SCP, which facilitates the collection of malware samples [[15](https://docs.cowrie.org/en/latest/README.html#what-is-cowrie)].

Thus, for the lab, the medium-interaction format is ideal, since there is no need to have real services; the emulated services are enough to allow interesting actions such as handling files and users (through `/etc/passwd`). On the other hand, this system requires fewer resources, which is beneficial for introducing it into one of the servers instead of requiring other QEMU-emulated machines.

### VPN 
Another potentially interesting countermeasure is the VPN, or virtual private network. This technology enables communication between two devices through a private network created over the Internet—it allows secure communication across an insecure public network. Its operation is based on hiding IP addresses and encrypting data so that no unauthorized party can read it [[16](https://aws.amazon.com/es/what-is/vpn/)].

A VPN connection normally consists of two devices: a VPN client (the local machine from which communication is initiated) and a VPN server. Once the connection is established, any communication from the local device passes through the server via a secure tunnel—from that point onward, the apparent origin of the data is the server. This tunnel prevents third parties, including service providers, from seeing the data. This is possible thanks to strong encryption of the communication while it passes through the tunnel between the client machine and the server [[16](https://aws.amazon.com/es/what-is/vpn/)].

Because of all the advantages described above, this technology was chosen to enable the creation of a secure external-to-internal communication path. This simulates a typical scenario in which a company can grant its workers remote access to the corporate network.

#### OpenVPN
One of the most popular tools for creating a VPN server is OpenVPN. This open-source technology makes it possible to create a server that establishes a secure tunnel with clients. In addition, it provides the client software necessary for those clients to connect to the VPN server [[17](https://nordvpn.com/es/blog/what-is-openvpn)].

To establish these secure communications, OpenVPN consists of several steps, beginning with the authentication process on the VPN server, followed by tunnel configuration, then the encapsulation and encryption of the data to be transmitted, and finally the transmission of that information through the created tunnel [[17](https://nordvpn.com/es/blog/what-is-openvpn)].
![image](https://github.com/user-attachments/assets/7567b755-2db1-4440-88b0-25526a69420a)

### Access Point Simulation
In addition to creating machines and establishing countermeasures, it is necessary to create wireless access points for the Wi-Fi network attacks that will be studied. In a simulated environment, there are no wireless interfaces by default, nor can Docker create them within its networks. Therefore, Linux kernel features are used. Specifically, the `mac80211_hwsim` test module is used, a software simulator of IEEE 802.11 radios—wireless interfaces for WiFi—intended for testing and development in Linux. This module generates multiple virtual Wi-Fi interfaces that emulate real cards and communicate with each other by sharing a channel (command `modprobe mac80211_hwsim radios=<num-interfaces>`) [[18](https://kernel.org/doc/html/next/networking/mac80211_hwsim/mac80211_hwsim.html)].

Thanks to the simulation of these kinds of interfaces, it is possible to use technologies that simulate the behavior of wireless networks. Specifically, Hostapd and `wpa_supplicant` are used to establish the access point and connect to it, respectively. Hostapd is based on the use of a wireless interface (real or simulated) to generate an IEEE 802.11 access point capable of using IEEE 802.1X/WPA/WPA2/EAP/RADIUS in WiFi networks [[19](https://wireless.docs.kernel.org/en/latest/en/users/documentation/hostapd.html)]. On the other hand, `wpa_supplicant` handles wireless interfaces and the protocol details necessary for connecting to WiFi access points under IEEE 802.11 [[20](https://docs.voidlinux.org/config/network/wpa_supplicant.html)].

Finally, one of the WiFi authentication protocols mentioned among Hostapd's capabilities (and among those studied) is EAP/RADIUS, so the option of launching a server with this authentication technology must be considered. For this purpose, the most widely used service for configuring RADIUS authentication servers was chosen: FreeRADIUS [[21](https://www.freeradius.org/)].

### Kali Linux
The main idea behind this lab is to test tools used to launch attacks against wireless networks, so a Kali Linux device (one of the Docker machines) was chosen to perform the attacks. This is due to Kali's readiness and the tools it includes for carrying out attacks of all kinds, making it an ideal option for learning while avoiding costly setup steps. Kali Linux is an open-source system based on the Debian distribution, together with a large set of tools and features dedicated to security and penetration testing (especially relevant to the goal of this lab) [[22](https://www.kali.org/)].

Among the tools provided by the Kali Linux environment, the most relevant for this project are those related to WiFi network attacks. In particular, the use of the `aircrack-ng` package stands out, since it includes a set of tools for wireless traffic capture and password cracking/capture [[23](https://www.infosecinstitute.com/resources/penetration-testing/kali-linux-top-8-tools-for-wireless-attacks/)].

### ShellShock
In addition to the attacks directly related to wireless networks, other attacks that allow a more complete exploitation of everything introduced in the lab must also be considered. This led to the idea of integrating several machines exposing vulnerable services, with the goal of showing the effects of what happens when an attacker gains illegitimate access to our network. For this reason, one of the vulnerable machines introduced is a device that includes a well-known vulnerability in UNIX systems called ShellShock (CVE-2014-6271) [[24](https://www.incibe.es/en/incibe-cert/early-warning/vulnerabilities/cve-2014-6271))].

The ShellShock vulnerability, also known as Bashdoor (officially GNU Bash Remote Code Execution Vulnerability), consisted of an attack that allowed remote code execution on millions of servers and other computers around the world. This flaw was mainly based on the use of HTTP servers running FastCGI or CGI (which allow the execution of external scripts), making it possible to expose a Bash console to users at a URI such as `http://myweb.com/cgi-bin/script.sh`. This causes the server to execute `script.sh` with an interpreter such as Bash [25](https://journal.espe.edu.ec/ojs/index.php/geeks/article/view/279)].

This exposure becomes truly dangerous because such servers usually pass a set of environment variables to the scripts they execute. In this way, the possibility offered by Bash to assign a function as the value of an environment variable is exploited. Moreover, in vulnerable versions Bash even allows any command appearing after a closed function to be executed [25](https://journal.espe.edu.ec/ojs/index.php/geeks/article/view/279)].
```http
GET /cgi-bin/vulnerable HTTP/1.1
User-Agent: () { :; }; /bin/cat /etc/passwd
```
This would be an example of how to execute a command (`/bin/cat /etc/passwd`) by altering the header of an HTTP request to change the `User-Agent`, which translates into placing that function and everything following it into the `HTTP_USER_AGENT` environment variable. This variable is then passed to the script being executed, causing it to run the malicious command.
```bash
HTTP_USER_AGENT='() { :; }; /bin/cat /etc/passwd'
```

### Metasploitable3
On the other hand, a well-known machine exposing a number of vulnerable services was also included, designed precisely to serve as training for offensive cybersecurity professionals who want to strengthen their skills, which fits perfectly with the main goal of this project. This machine is Metasploitable 3 [[26](https://www.rapid7.com/blog/post/2016/11/15/test-your-might-with-the-shiny-new-metasploitable3/)], an open-source virtual machine arising from the Metasploitable project funded by Rapid7 [[27](https://www.rapid7.com/products/metasploit/)]. Specifically, Metasploitable 3 is based on an Ubuntu 14.04 machine (the one used for this lab) or Windows Server 2008, deploying services with vulnerabilities such as SSH or MySQL.

Metasploit is not only a project that offers vulnerable machines, but also helps exploit them thanks to a large database that allows users to import and export exploits. This makes it much easier to find the ideal exploit not only to gain access to Metasploitable machines, but also for other real services [[28](https://riull.ull.es/xmlui/bitstream/handle/915/28744/Pentesting%20en%20entornos%20controlados.pdf)]. This functionality provided by Metasploit greatly facilitates the first steps of professionals entering the world of cybersecurity, which is the main reason for its use in the designed environment.

## Lab Diagram
Here we can see the configuration of the lab, both from a more visual and more schematic point of view:
![Esquema-Redes](https://github.com/user-attachments/assets/194803dd-dcd5-4c80-b6f5-c387f4b2d2bc)

```text
# General repository layout
📁 dmz
├── 📁 dmz1
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 dmz2
│   ├── Dockerfile
│   ├── start.sh
│   └── ...

📁 external
├── Dockerfile
├── start.sh
└── ...

📁 fw
├── Dockerfile
└── start.sh

📁 internal
├── 📁 int3
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 int4
│   ├── Dockerfile
│   └── start.sh
├── 📁 int12
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 wireless
│   ├── 📁 AP
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 attacker
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 client3
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 client12
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...

📄 docker-compose.yml  
📄 launch.sh  
📄 README.md  
📄 stop.sh
```

Below, the files that build the environment are described in more detail, starting with some details of the [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/docker-compose.yml) file that defines the different machines and internal networks created with Docker:
```yaml
# docker-compose.yml file
...
networks:  
  external-network: 
    driver: bridge 
    ipam:
      config:
        - subnet: 10.5.0.0/24 
          gateway: 10.5.0.254 

  DMZ:
    driver: bridge
    ipam:
      config:
        - subnet: 10.5.1.0/24
          gateway: 10.5.1.254

  internal-network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.5.2.0/24
          gateway: 10.5.2.254
```
```bash
# start.sh files with wired connections
...
route add default gw 10.5.0.1
route del default gw 10.5.0.254
...
```
The first thing to note is how the different subnets used to define the lab are created. It can be seen that the address ending in `.254` is used as the gateway in each of them, which differs from what was mentioned in the introduction, where the addresses ending in `.1` were taken as such (those corresponding to the interfaces of `fw`). This is because in other places, such as the definition of each machine, these addresses are used:
```yaml
# Some examples
...
# Firewall device
  fw: 
    image: bin/fw 
    build: ./fw
    container_name: fw
    networks: 
      external-network:
        ipv4_address: 10.5.0.1 
      DMZ:
        ipv4_address: 10.5.1.1
      internal-network:
        ipv4_address: 10.5.2.1
    privileged: true 
    tty: true

# External device
  external:
    image: bin/external
    build: ./external
    container_name: ext1
    networks:
      external-network:
        ipv4_address: 10.5.0.20 
    depends_on:
      - fw
    privileged: true
    tty: true
...
```
`docker-compose` does not allow the same IP address to be written twice in a [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/docker-compose.yml) file, so these `.254` addresses are used in order to define the gateways, but that configuration is then changed inside the `start.sh` files where necessary. In addition, the previous example shows that the machines receive their network configuration (IP and subnet) when the machine itself is defined in this `.yml` file.

On the other hand, it can be seen that all machines define the `privileged: true` option, granting elevated permissions on the machine that will act as host. These permissions are necessary to work with network interfaces and other details, but especially on the wireless machines, which do not take any of the previously described networks (`network_mode: "none"`), since it is necessary to create the wireless interfaces from a Linux kernel machine acting as host (the machine used to launch the lab):
```yaml
# Some examples inside docker-compose.yml
...
# WLAN devices
  access-point-1:
    image: bin/access-point
    build: ./internal/wireless/AP
    container_name: ap
    networks:
      internal-network:
        ipv4_address: 10.5.2.24
    depends_on:
      - fw
    privileged: true
    tty: true

  client-1:
    image: bin/client
    build: ./internal/wireless/client12
    container_name: client1
    network_mode: "none"
    depends_on:
      - access-point-1
    privileged: true
    tty: true
...
```
This is because Docker has a limitation when using the host Linux kernel, so it cannot execute commands such as `modprobe mac80211_hwsim` to create virtual wireless interfaces. Due to the need to create these wireless networks, the [`launch.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/launch.sh) file appears, which is responsible for creating those interfaces and assigning them to the Docker machines that will use them:
```bash
# Snippet from launch.sh to launch Docker machines and create wireless interfaces
...
docker-compose build
docker-compose up -d
sleep 20
# docker-compose ps

# Assign wireless interfaces to containers
# Create virtual wireless interfaces
modprobe mac80211_hwsim radios=5
...
```
In addition, not only do those interfaces need to be created, but Linux namespaces are also used so that each created interface is used by a single machine within the wireless network:
```bash
# Snippet from launch.sh where namespaces are handled
...
# Associate each wireless interface to pid container network namespace
ln -s /proc/"$AP_PID"/ns/net /var/run/netns/"$AP_PID"
ln -s /proc/"$CLIENT1_PID"/ns/net /var/run/netns/"$CLIENT1_PID"
ln -s /proc/"$CLIENT2_PID"/ns/net /var/run/netns/"$CLIENT2_PID"
ln -s /proc/"$CLIENT3_PID"/ns/net /var/run/netns/"$CLIENT3_PID"
ln -s /proc/"$ATTACKER_PID"/ns/net /var/run/netns/"$ATTACKER_PID"
iw phy "$WLAN0_PHY" set netns "$AP_PID"
iw phy "$WLAN1_PHY" set netns "$CLIENT1_PID"
iw phy "$WLAN2_PHY" set netns "$CLIENT2_PID"
iw phy "$WLAN3_PHY" set netns "$CLIENT3_PID"
iw phy "$WLAN4_PHY" set netns "$ATTACKER_PID"
...
```
In the same way, the use of the [`stop.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/stop.sh) file is strongly recommended, since it is responsible for destroying the namespace assignments and the created interfaces:
```bash
#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Exec like root please" >&2
  exit 1
fi

# Clean symlinks in netnamespaces
find -L /var/run/netns -type l -delete

# Destroy wireless interfaces and stop services
modprobe mac80211_hwsim -r
docker-compose down
```
Once the files that define the lab in more general terms have been analyzed—that is, the configuration files that bring the machines up—it is time to continue examining the configuration of each of the devices that make up the different networks.

### External Network
Here there is only a single Ubuntu machine based on the `httpd` image [[29](https://hub.docker.com/_/httpd)] provided directly by Apache, with everything needed to easily create an Apache HTTP/HTTPS server. In addition to that, it contains all the configuration files ([`index.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/external/index_ext1.html) and [`ssl.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/external/ssl.conf)) to expose an HTTP and HTTPS service showing a simple login page (although it is not actually functional; it only serves to show how a page can easily be cloned). On the other hand, it contains everything needed (keys and [`client.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/external/client.conf), that is, the OpenVPN client configuration file) to establish the VPN connection with the server intended for it inside the internal network, as well as a startup file ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/external/start.sh)) that simply runs the SSH service in the foreground so that connections can be made for testing (this will be repeated on all machines except `fw`, adding some small extra detail where necessary, such as launching the services they implement).
```text
📁 external
├── Dockerfile
├── ca.crt
├── client.conf
├── client.crt
├── client.key
├── index_ext1.html
├── ssl.conf
└── start.sh
```

### DMZ Network
On the other hand, the DMZ network contains two devices with similar configurations, but with small differences in the countermeasures they implement. On the one hand, there is DMZ1, a machine focused on offering protection based on the Cowrie honeypot. Meanwhile, DMZ2 aims to provide a higher level of protection for SSH connections by adding *hardening* features.
```text
📁 dmz
├── 📁 dmz1
│   ├── Dockerfile
│   ├── index_dmz1.html
│   ├── ssl.conf
│   └── start.sh
└── 📁 dmz2
    ├── 📁 .ssh
    ├── Dockerfile
    ├── banner.sh
    ├── google_authenticator
    ├── index_dmz2.html
    ├── jail.local
    ├── sshd_config
    ├── ssl.conf
    ├── start.sh
    └── syslog.conf
```

#### DMZ1
Once again, a `Dockerfile` can be seen that starts from Apache's `httpd` image to generate the corresponding HTTP/HTTPS server with the help of the [`ssl.conf`](http://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz1/ssl.conf) files (HTTPS connection) and [`index_dmz1.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz1/index_dmz1.html) (main page). On the other hand, the Cowrie configuration stands out, since it is carried out not through [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz1/start.sh), but through the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz1/Dockerfile) itself:
```dockerfile
# Portion of the Dockerfile that configures the honeypot
...
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
    echo "carlos:x:1234" >> /home/cowrie/cowrie/etc/userdb.txt
...
```
Unlike the previous device, this one not only exposes SSH, but also configures an `iptables` rule with the goal of redirecting external traffic that attempts an SSH connection (port 22 is the default SSH port) to port 2222, where the Cowrie server is exposed. In this way, a trap is laid for external users while normal SSH access is still allowed for legitimate users (mainly from the internal network).
```bash
iptables -t nat -A PREROUTING -s 10.5.0.0/24 -p tcp --dport 22 -j DNAT --to-destination :2222
```

#### DMZ2
This machine has the same capabilities to expose an HTTP/HTTPS web service with a short message allowing its origin to be recognized (“Hello! I am the server known as DMZ2”) thanks to the [`ssl.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/ssl.conf) files (HTTPS connection) and [`index_dmz2.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/index_dmz2.html) (main page). However, it replaces Cowrie as a countermeasure with SSH protection through two-factor authentication ([`google_authenticator`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/google_authenticator)) combined with the ability to block traffic from IP addresses that have made too many failed attempts (2 in this case). This is possible thanks to the *fail2ban* service (configured in [`jail.local`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/jail.local)), which works together with SSH by blocking IPs that make too many attempts through `iptables` rules.

In addition, the [`syslog.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/syslog.conf) file is necessary to tell the *syslog* service that it must register failed SSH connection attempts, as well as the [`sshd_config`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/sshd_config) file to change the SSH configuration, thus allowing the addition of all these features, in addition to moving SSH to port 2222 so that attackers cannot identify it directly (the default is 22). On the other hand, the [`.ssh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config/dmz/dmz2/.ssh) directory is set up to store the keys required for public/private key authentication to the SSH service. It was also decided to add a little more detail to the DMZ2 server by customizing the *banner* ([`banner.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/dmz/dmz2/banner.sh)) displayed after authenticating over SSH.

### Internal Network (Wired)
This network implements two simple Ubuntu machines acting as normal users of the internal network with the ability to access the servers for administration, together with another machine with similar characteristics that also provides a VPN server through OpenVPN. In addition, a machine with the ShellShock vulnerability is installed, as well as a wireless access point that is connected to the internal network by cable so that the wireless network it creates becomes part of the internal network.
```text
📁 internal
├── 📁 int12
│   ├── 📁 .ssh
│   ├── Dockerfile
│   └── start.sh
├── 📁 int3
│   ├── Dockerfile
│   ├── ca.crt
│   ├── dh.pem
│   ├── server.conf
│   ├── server.crt
│   ├── server.key
│   └── start.sh
├── 📁 int4
│   ├── Dockerfile
│   └── start.sh
└── 📁 wireless
```

#### int12
The int1 and int2 machines are two identical machines implementing a simple Ubuntu 24.04 machine to which only an SSH service is added so that they remain running and can be connected to for administration and lab testing purposes. This can be seen in the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int12/Dockerfile) and the startup script [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int12/start.sh). In addition, they contain a [`.ssh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int12/.ssh) directory that allows public/private key authentication to the DMZ2 server's SSH service (password for using the private key = `1234`). Finally, an entry added to the routing table can be seen in the startup file:
```bash
# Portion of start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24
...
```

This entry is used so that the internal network can locate the wireless subnet within this network (through the access point) and communicate with it easily. This behavior is repeated in the rest of the wired machines of the internal network (except for the access point, which is already directly connected to that subnet).

#### int3
It has the same characteristics as the previous two machines except for the SSH keys to connect to DMZ2 (although it can still connect using username and password). Thus, the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int3/Dockerfile) has a very similar configuration, adding into the image to be created the files related to the keys of the OpenVPN service it exposes on port 1194, as well as the [`server.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int3/server.conf) configuration file for that same service, where the characteristics of the VPN server are defined. In addition, in [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int3/start.sh) there can be seen, beyond what is present on int1 and int2, a set of `iptables` rules that allow the VPN connection:
```bash
# Portion of start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24

# Allow and config VPN
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
...
```

More specifically, traffic passing through this machine (disabled by default) is allowed so that it can be redirected to the internal network, where the subnet `10.8.0.0/24` represents a network created by the VPN server to mask the real source IPs of connecting clients (specified in [`server.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int3/server.conf)). In this way, traffic coming from that subnet is redirected through int3 to the internal network (leaving through int3's `eth0` interface), being masked with this machine's source IP.

#### int4
This machine represents a vulnerable device based on the `vulnerables/cve-2014-6271` image [[30](https://hub.docker.com/r/vulnerables/cve-2014-6271)], as can be seen in its [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int4/Dockerfile). In this way, a machine is created that is actually Ubuntu, but simulates a vulnerability that is typical of Windows, which allows the addition of the SSH service common to all the machines in the lab, together with a routing table modification to allow access to the wireless subnet ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/int4/start.sh)):
```bash
# Portion of start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24
...
```

### Internal Network (Wireless)
In addition to the wired machines, the internal network includes a `10.5.2.128/26` subnet of wireless machines, where the access point with IP `10.5.2.129` is the device that manages this communication and allows connection through the internal network with the rest of the machines (it has the same restrictions as the wired machines, since communication will pass through `fw` once it traverses the access point). Just as in the wired part, the same structure is repeated with two simple Ubuntu 24.04 machines together with a vulnerable machine, with the addition of an attacker machine based on Kali Linux, intended to be the machine mainly used to carry out the various attacks studied.
```text
📁 wireless
├── 📁 AP
│   ├── Dockerfile
│   ├── clients.conf
│   ├── dhcp.conf
│   ├── eap
│   ├── hostapd-config.conf
│   ├── hostapd.conf
│   ├── start.sh
│   └── users
├── 📁 attacker
│   ├── Dockerfile
│   ├── clients.conf
│   ├── dhcp.conf
│   ├── eap
│   ├── freeradius-server-3.2.7.tar.gz
│   ├── hostapd-config.conf
│   ├── hostapd.conf
│   ├── radius.conf
│   ├── start.sh
│   ├── ssh_passwords.txt
│   ├── ssh_usernames.txt
│   ├── users
│   ├── wpa_supplicant-config.conf
│   └── wpa_supplicant.conf
├── 📁 client12
│   ├── Dockerfile
│   ├── start.sh
│   ├── wpa_supplicant-config.conf
│   ├── wpa_supplicant_wlan1.conf
│   └── wpa_supplicant_wlan2.conf
└── 📁 client3
    ├── Dockerfile
    ├── start.sh
    ├── wpa_supplicant-config.conf
    └── wpa_supplicant.conf
```

Here there are several files common to the different machines, starting with [`wpa_supplicant.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client3/wpa_supplicant.conf), [`wpa_supplicant_wlan1.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client12/wpa_supplicant_wlan1.conf), and [`wpa_supplicant_wlan2.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client12/wpa_supplicant_wlan2.conf), which are very similar regardless of the machine in which they are found, making it possible for the various clients to connect to the access point (they are also included on the attacker to facilitate connection once the key is obtained). These files may change depending on the branch they are in, varying according to the security protocols simulated in each of them, since they specify the authentication credentials for the access point.

Another similar file on all clients is [`wpa_supplicant-config.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client3/wpa_supplicant.conf), which configures the *wpa_supplicant* service to allow all kinds of configurations, including WEP, thanks to the download and compilation of this tool, as can be seen in any of their [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client12/Dockerfile) files. In addition, these machines contain a startup file [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client3/start.sh) where the services needed to connect to the access point are executed (except on the attacker, which has the tools, but by definition should not know the connection details):
```bash
# Portion of start.sh
...
wpa_supplicant -i "$IFACE" -c wpa_supplicant.conf -B
sleep 2
dhclient "$IFACE"
...
```
This file also shows how WLAN clients register the domain `carlos.web.com` associated with IP `10.5.0.20`; that is, they associate this domain with the service exposed by the external machine (a website with a fake login process). However, this is left commented out in the destination file (`/etc/hosts`), since it is only a countermeasure left available to be activated after seeing the adverse effects of an attack:
```bash
echo "10.5.0.20      carlos.web.com" >> /etc/hosts
```

In addition, two `.txt` files are shown, [`ssh_passwords.txt`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/attacker/ssh_passwords.txt) and [`ssh_usernames.txt`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/attacker/ssh_usernames.txt), which are respectively dictionaries of passwords and usernames that will be used to perform brute-force attacks trying all possible combinations to break the credentials of an SSH server.

#### AP
This machine starts from the `freeradius/freeradius-server:3.2.7` image [[31](https://hub.docker.com/layers/freeradius/freeradius-server/3.2.7/images/sha256-42b05de4405b1e745686b9ed0f70307fd43e998b850b3e6bd936733a8c260595)], which is an Ubuntu 22.04 image prepared to provide a FreeRADIUS RADIUS server. This is because the configuration shown corresponds to the [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS) branch, as it is the most complete of all; however, in the rest of the branches the base image is `debian:bookworm-slim`, allowing in both cases a similar configuration in which the *hostapd* tool is installed and compiled, as can be seen in the corresponding [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/Dockerfile) files. On the other hand, the exposure of the SSH service for administration—common to all machines—can also be seen, to which a set of `iptables` rules are added in [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/start.sh) so that it can perform the access point function that redirects communications leaving the wireless network toward the wired network and vice versa.
```bash
# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Drop forwarding traffic by default
iptables -P FORWARD DROP

# Allow forwarding LAN traffic
iptables -A FORWARD -i wlan0 -o wlan0 -s 10.5.2.128/26 -d 10.5.2.128/26 -j ACCEPT

# Allow and masquerade forwarding traffic from wireless to wired interface 
iptables -A FORWARD -s 10.5.2.128/26 -i wlan0 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.5.2.128/26 -i eth0 -o wlan0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.128/26 -o eth0 -j SNAT --to 10.5.2.24

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

It can also be seen how it allows WLAN communication between wireless machines and internal (*loopback*) traffic. In addition, it can be seen how it starts the services related to its role as an access point:
```bash
# Setup DHCP
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
dhcpd -cf /etc/dhcp/dhcpd.conf wlan0

# Setup hostapd (access point) 
freeradius -i 127.0.0.1 -p 1812 
sleep 2
hostapd /ap/hostapd.conf -B
```

As for the configuration files, those common to all branch versions should be highlighted, such as [`hostapd.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/hostapd.conf) and [`hostapd-config.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/hostapd-config.conf), which are similar to their *wpa_supplicant* counterparts, being the configuration of the access point to be created by *hostapd* and the compilation configuration of this tool to enable all options (mainly because WEP is disabled by default), respectively. The [`dhcp.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/dhcp.conf) file is also common to all branches; it defines the DHCP service that provides IP addresses to connecting clients.

On the other hand, files such as [`clients.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/clients.conf), [`eap`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/eap), and [`users`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/AP/users) are part of the WPA/WPA2-Enterprise configuration exclusive to the [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS) branch; these files make up the configuration of the FreeRADIUS service. They define the users (PEAP is used), as well as the configuration of the provided server.

#### client12
Once again, a configuration common to two simple machines (client1 and client2) is presented, both based on the `debian:bookworm-slim` image and implementing only the SSH service in order to remain running once started with Docker ([`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/internal/wireless/client12/Dockerfile)) and allow administrative connections to them. They only introduce what is related to connecting to the Wi-Fi network through *wpa_supplicant*, which is common to the rest of the machines, as already explained.

#### client3
Another simple machine is also shown that uses SSH communication and everything necessary to connect to the access point through *wpa_supplicant*. However, this machine is based on the `kirscht/metasploitable3-ub1404` image [[32](https://hub.docker.com/r/kirscht/metasploitable3-ub1404)], which implements a vulnerable Metasploitable3 machine [[26](https://www.rapid7.com/blog/post/2016/11/15/test-your-might-with-the-shiny-new-metasploitable3/)] based on Ubuntu 14.04 (allowing a configuration similar to client1 and client2) in order to create vulnerable services.

#### attacker
The attacker machine is the most important of all, since it is the one mainly handled when carrying out the various studied attacks. It starts from a Kali Linux *Rolling* machine and implements Kali tools for network security testing (`kali-tools-wireless`), as well as the common *wpa_supplicant* configuration needed to establish communication with the access point if necessary (although by default it does not connect so that the attacks make sense). It also includes, exclusively in this branch (based on the [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS) branch), everything required to establish a FreeRADIUS server, necessary to gain illegitimate access to the access point using that same technology.

### `fw` Machine (in All Networks)
Another machine of great importance is the one representing the *firewall*, which acts as the intermediate point joining all the networks. This machine has a basic Ubuntu 24.04 configuration exposing the same SSH service as the rest of the lab ([`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/fw/Dockerfile)). However, it implements a series of `iptables` rules that make its firewall mission possible ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/fw/start.sh)):
```bash
# Portion of start.sh related to firewall rules
...
# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Change defaults policies to drop input and forward traffic and allow output and loopback traffic
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Allow response traffic at TCP and UDP traffic to fw machine
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT             #icmp packets are considered RELATED traffic to iptables
iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT                       #Accept ping requests to fw (changed by limit option)

# Allow response traffic at ICMP, TCP and UDP traffic that go through fw machine
iptables -A FORWARD -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT                        #icmp packets are considered RELATED traffic to iptables

# Allow TCP, UDP and ICMP since intranet to extranet
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p tcp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p udp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p icmp -j ACCEPT

# Masquerade Intranet to extranet comunications (using SNAT because IP is always the same)
iptables -t nat -A POSTROUTING -s 10.5.2.0/24 -d 10.5.0.0/24 -j SNAT --to 10.5.0.1

# Allow HTTP request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT

# Limit icmp request to fw (avoid DOS attacks)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/minute --limit-burst 10 -j ACCEPT

# Allow SHH admin comunications since intranet to dmz servers
# iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.0/24 -p tcp --dport 22 -j ACCEPT        # for more secure divide this rule in two:
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT           # for more restrictive admin conexion
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Allow all internal network to admin dmz servers
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT

# Allow HTTPS request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT

# Define VPN conection 
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            #neccesary for vpn admin connection (for more restrictive admin conexion)
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT               
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.2.22 -p udp --dport 1194 -j ACCEPT
iptables -A FORWARD -s 10.5.2.22 -d 10.5.2.0/24 -p udp --sport 1194 -j ACCEPT

# Allow external SSH traffic to dmz1 machine (in this machine this traffic is redirect to cowrie honeypot)
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT
...
```

[`Back to the introduction`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/main)
