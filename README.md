# WPA/WPA2 PSK Cracking Lab
## Introduction

Now it is time to continue carrying out attack tests with the next version of the security protocol that arose after the IEEE realized its flaws and proposed two algorithms to replace the old WEP: WPA as a temporary solution and WPA2 as the definitive version. In addition, the same methodology as in the [WEP](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WEP) attack will be followed, first discussing how the WPA/WPA2 PSK protocol works, followed by the attack itself, as well as the corresponding recommendations and countermeasures.

## WPA/WPA2 PSK Security Protocols

Due to the many imperfections that made the WEP protocol weak, in 2003 a security mechanism known as WPA emerged. This protocol aimed to mitigate WEP’s defects while a higher-quality one was being created, which would later become known in 2004 as WPA2. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Despite being an intermediate solution, WPA represented a major improvement in security compared to its predecessor, WEP: [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]
- **More robust encryption:**  
  WPA began to implement longer pre-shared keys (256 bits), as well as IVs that doubled the previous length used by WEP (48 bits instead of the previous 24). In addition, there is the possibility of using another encryption mechanism for communications: the AES block cipher algorithm (still robust today) with 256-bit keys.

- **Improved integrity control:**  
  Another major weak point of WEP was the use of CRC to protect the integrity of communications, which was a weak mechanism. Instead, WPA introduced the use of MIC (Message Integrity Code). The main difference between MIC and a simple hash or MAC is that MIC helps detect and prevent modifications more effectively.

- **Use of temporal keys:**  
  WPA introduced the use of temporal keys to encrypt packets; each packet uses a new key generated from the master key established when the communication begins (this, in turn, is generated from the pre-shared key (PSK) and other parameters that are sent in plaintext). The downside is that, in its older modes, this protocol still used RC4/MIC when transmitting some packets.

- **Support for an authentication server:**  
  The ability to connect an access point to an authentication server was introduced, avoiding the exclusive use of pre-shared keys. This variant is intended for organizations, using per-user credentials/passwords or certificates.

As already mentioned, WPA introduced the ability to use AES as the encryption algorithm, but it did not require it. Thus, the main difference between WPA and its successor, WPA2, is that the latter requires the use of the AES standard (more robust than RC4) in the encryption process. While WPA’s TKIP uses RC4 and MIC to protect confidentiality and integrity, WPA2 mandates the use of CCMP, which implements the AES and CBC-MAC algorithms. 

The CCMP protocol is now responsible for generating temporal keys in a more secure way than TKIP by using the AES algorithm instead of RC4. In addition, it replaces MIC-based integrity checking with CBC-MAC, which is also a more robust algorithm.

On the other hand, thanks to the introduction of support for authentication through a server intended for this task, two types of protocol—and therefore two types of attack—stand out. Those relating to WPA/WPA2 PSK protocols (traditional shared-key versions), and those relating to WPA/WPA2 Enterprise protocols (which use an authentication server).

Focusing on the traditional versions (PSK), both are attacked using the same vulnerability related to the authentication and master key generation process, a protocol known as the *4-way handshake*:  
![image](https://github.com/user-attachments/assets/e03f855a-320c-4ed8-af46-716354a7cc02)

### Vulnerabilities 

Attacks are usually based on collecting this process in order to obtain all the data used in the generation of the master key (Primary Master Key, NONCE, etc.). Once all the master key generation data is known—the key from which the TKIP or CCMP protocols will start—dictionary attacks are often used. These attacks test typical pre-shared keys together with the gathered data in order to generate valid master keys. Thus, if the attacker manages to find the master key that is actually being used, not only can they read the packets exchanged with that legitimate user, but they may also be able to obtain the pre-shared key (PSK) that grants access to the network. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Another common attack is the so-called deauthentication attack, which is more of a complement to the previous attacks. This attack forces one of the legitimate clients to disconnect, causing it to reconnect immediately and generate a new 4-way handshake that can then be captured. This is especially useful if the network has few clients, since otherwise it could take a long time to wait for a new legitimate client to connect and generate this packet sequence. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Both will now be used in a process for attacking either of the two protocols. Since both versions share the same attack vectors, only the more robust one, WPA2, will be shown, which is configured by default as the access point in Hostapd (in the AP). If you want to change it, uncomment the option in the [`Dockerfile`]() of the AP that copies the configuration for WPA and comment out the WPA2 one:

## Attacking WPA/WPA2 PSK
After configuring the desired WPA version for the attack, the environment must be started (making sure you are on this branch) and a connection established with the Kali Linux machine (you must wait until everything has been configured first, for safety reasons):
```bash
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
Once inside, the monitor mode on the attacker’s wireless interface (`wlan4`) is enabled again in order to capture packets that are not addressed to this machine. This is done with the goal of capturing the *4-way handshake* processes that contain the details used to establish the communication and the keys, as mentioned earlier.
```bash
airmon-ng start wlan4
```
`Reminder:` This may generate a monitor-mode interface with the same name or something similar to `wlan4mon`; also check with `ifconfig` that the attacker machine’s interface is indeed `wlan4`.

With monitor mode enabled, `airodump-ng` can now be launched in order to display the details of the access point that is going to be attacked:
```bash
airodump-ng wlan4mon
```
![image](https://github.com/user-attachments/assets/4e43bb6e-0c12-4743-9656-97f7f43e0075)

Once the target access point, `WPAnetwork`, has been located, the idea is to capture a *4-way handshake* process from a legitimate client that begins its connection to the access point. To do this, the same command can first be optimized so that it listens only to the traces related to that access point: [[37](https://www.aircrack-ng.org/doku.php?id=cracking_wpa)]
```bash
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon
```
* `-c 6`: channel on which the access point is operating.
* `--bssid 02:00:00:00:00:00`: MAC address of the access point.
* `-w wpa-wpa2`: name (without extension) of the files where the captured packets will be stored.
* `wlan4mon`: name of the attacker interface.
![image](https://github.com/user-attachments/assets/8556f7c8-c786-4b4e-bec8-4473200427b7)

`Reminder:` This process generates several files in which it stores the captured packets, with the `.cap` file being the most important, since it stores the packets in a format intended to be read by other tools such as `wireshark` or `aircrack-ng`.

At the bottom, the active clients sending packets to the access point are shown, so what we need is to capture a key negotiation (4-way handshake) from one of them or from another device that reconnects (which is more likely). Normally these attacks are carried out on networks with a large volume of clients, where it is common for one of them to disconnect and reconnect or for a new legitimate client to arrive. However, if we simply wait for that to happen, in some cases it may take a long time before seeing an `EAPOL` or `WPA handshake` message indicating that the authentication/key negotiation process has been captured.

To speed up this process, the ideal approach would be to force one of the current clients to disconnect, trusting that it has an automatic reconnection method that makes it connect back to the access point, thereby generating the desired *4-way handshake*. To do this, the `aireplay-ng` tool can be used again:
```bash
# In another terminal (this can be done with other victim MACs)
docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon
```
- `-0`: deauthentication (an attack that forces deauthentications).
- `1`: number of deauthentication messages sent.
- `-a 02:00:00:00:00:00`: MAC address of the access point.
- `-c 02:00:00:00:02:00`: MAC address of the client to deauthenticate (if omitted, it is launched against all clients).
- `wlan4mon`: is the interface name.

Thus, after several deauthentication attempts—or simply after waiting without this acceleration—the message indicating the capture of the shared key negotiation process used by the client and the access point is detected:
![image](https://github.com/user-attachments/assets/ad332206-8d70-48e6-b799-60073a6c3bd5)

This process not only establishes the key that will be used for encryption, but also uses the master key or pre-shared key itself, which grants access to the network; in other words, it is the password requested by the WiFi access point when someone tries to connect to it. Thus, through a brute-force dictionary process (otherwise this process can be very long, especially with robust keys), this pre-shared key can be recovered from the collected data, as well as the key with which the client that owns this process encrypts the data shared with the access point or vice versa. To do this, the `aircrack-ng` command is used again with the following options:
```bash
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```
- `/usr/share/wordlists/rockyou.txt`: dictionary of passwords (it is advisable to use an absolute path; in this case a typical path and filename are used).
- `-b 02:00:00:00:00:00`: MAC address of the access point.
- `wpa-wpa2*.cap`: use all `.cap` files beginning with the name `wpa-wpa2` (if several `airodump-ng` sessions are run with `-w wpa-wpa2`, files named `wpa-wpa2N.extension` will be generated).

As can be seen, this command also needs a dictionary or list of possible keys to test. It is typical here to try both lists collected from the Internet containing common passwords in general, and those containing default passwords for particular telecom companies. Therefore, it is recommended to choose the one that best fits the needs of each attack. In the case of this course, a Kali Linux list of typical passwords is used, one that is often combined with `aircrack-ng` to speed up the attack:
- `rockyou.txt`: this is a typical [`Kali Linux`](https://www.kali.org/tools/wordlists/) list.

After this, the desired password is obtained, granting access to the internal network (specifically the WLAN segment), which has serious consequences as seen in the [previous](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) chapter:
![image](https://github.com/user-attachments/assets/f29039c0-92b8-4106-bd58-c441fc656040)

`Note:` Some packet from the 4-way handshake process may not have been captured correctly, which can cause an error when executing this final part of the attack, meaning the capture must be repeated in the hope of having better luck.

Finally, it is recommended to repeat the attack by modifying the [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/Dockerfile) file to change the current configuration that uses WPA2 (the more robust of the two) by commenting out the line that refers to the `hostapd.conf` file for WPA2 and uncommenting the one referring to WPA (and then relaunching the lab to apply this modification). This is done to prove that the attack vector to which both versions are subjected is exactly the same:
![image](https://github.com/user-attachments/assets/652e2717-9ef0-45bc-ac37-54dffd6d83ac)

```bash
# Stop and relaunch the lab
sudo ./stop.sh
sudo ./launch.sh
```

### Countermeasures and recommendations
The main countermeasure to avoid these kinds of problems, if you still want to use WPA/WAP2, is to use a robust password as long as possible (63 characters maximum), for example:
```bash
X4r!tP7uNv#eLj29qWbR@KmZ8Yx&cDf9G3hTs%uQpL$JaMk0VbnEzHdCrL#oWy
```
This makes brute-force attacks too costly, even for high-powered computers, potentially requiring years to break it. It would also be ideal to change it from time to time, although that is a somewhat less practical measure. If the attack is repeated using this password, it is necessary to modify [`internal/wireless/AP/hostapd-WPA.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA.conf) or [`internal/wireless/AP/hostapd-WPA2.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA2.conf) (depending on the version used) to change this password in the access point, as well as in the respective clients’ [`internal/wireless/client12/wpa_supplicant.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/client12/wpa_supplicant.conf)/[`internal/wireless/client3/wpa_supplicant.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/client3/wpa_supplicant.conf), which are necessary to generate the *handshakes*, and finally relaunch the lab. In this way, it can be seen that the list no longer contains this password and therefore cannot find the access point key:
![image](https://github.com/user-attachments/assets/27f4bc05-99bd-4657-831e-5bd267923ee7)

```bash
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng wlan4mon
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon

# In another terminal
docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon

# After obtaining the handshake
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```
![image](https://github.com/user-attachments/assets/85543419-8925-456d-b451-5244e7edf712)
![image](https://github.com/user-attachments/assets/92d4c4c9-7e86-452f-ba03-17c40ebb9fc6)
<img width="698" height="476" alt="image" src="https://github.com/user-attachments/assets/ac6ccf13-e848-410b-9277-365434786feb" />

But for this to be truly effective, it is also necessary to ensure that the password is not present in these kinds of lists and does not contain personal information that is easily identifiable by attackers. On the other hand, one could consider upgrading to other security protocols such as the Enterprise versions that will be seen next (especially intended for corporations), or WPA3, the latest and most robust version of this protocol.

`Reminder:` It is advisable to repeat the [attacks](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) carried out after gaining access with the configuration in this chapter, in order to see that once inside, the security chosen for the access point becomes irrelevant, thus allowing the same results.

[`Previous lesson, attacks after gaining access`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks)
[`Next lesson, cracking WPS networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPS)
