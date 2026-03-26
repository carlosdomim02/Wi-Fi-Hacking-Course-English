# WPS Cracking Lab

## Introduction
This section aims to attack a technology implemented to make it easier for WPS clients to connect, which is often used in combination with other security protocols such as WPA, WPA2, or WPA3. To do so, the same methodology as in the previous attacks is followed, covering all the protocol details, as well as vulnerabilities and countermeasures against the executed attacks.

## WPS Protocol
WPS was introduced in 2006 as an additional configuration layer for WPA/WPA2 PSK protocols that makes it easier for users to connect. This type of configuration prevents users from having to enter the password (PSK), allowing other alternatives for the authentication process: [[39](https://ro.ecu.edu.au/ecuworks2012/146/)]
- 8-digit PIN
- Pressing a specific button on the access point
- Use of NFC technology

### Vulnerabilities
In the case of using buttons or NFC, exposing the device to the public can pose a serious security issue, since physical access to the access point is enough to connect to the network as a legitimate user. On the other hand, the options related to a short PIN (8 digits) open the door to brute-force attacks. Among these, attacks carried out with tools such as Reaver stand out [[38](https://www.kali.org/tools/reaver/)], which simply requires Python to be installed. [[39](https://ro.ecu.edu.au/ecuworks2012/146/)]

## Attacking WPS
Once located in the branch corresponding to the WPS version of access point security, the lab must be launched and a connection established to the Kali machine in the same way as in the previous chapters:
```bash
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
Once inside, the attacker’s wireless interface (wlan4) is again switched to monitor mode in order to capture packets that are not addressed to this machine. This is initially done in order to view which access points have WPS enabled, as well as other details such as the version of this protocol:
```bash
airmon-ng start wlan4
```
`Reminder:` This may create a monitor-mode interface with the same name or one similar to `wlan4mon`; it is also advisable to check with `ifconfig` that the attacker machine’s interface is `wlan4`.

With monitor mode active, `airodump-ng` can now be launched to view devices that have WPS enabled (using options such as `-c` to filter the results if needed):
```bash
airodump-ng --wps wlan4mon
```
<img width="927" height="179" alt="image" src="https://github.com/user-attachments/assets/59105bc4-089b-4929-8996-2b77aa0211be" />

After this, it can be seen that our target, the network with SSID `WPSnetwork`, is using the WPS protocol (possibly with PIN). To verify this information, the `wash` tool can also be used, which is part of the Reaver package that will be used to demonstrate the final brute-force attack:
```bash
wash -i wlan4mon
```
<img width="813" height="145" alt="image" src="https://github.com/user-attachments/assets/5726d5b3-5a32-4402-87d1-6d856382d4d5" />

`Note:` The interface must also be in monitor mode for this tool, since it needs the ability to listen to third-party communications.

Once it has been confirmed that the `WPSnetwork` network uses WPS, the Reaver tool can be used to launch the brute-force attack that tries all possible 8-digit PIN values that WPS may have enabled. Although we still do not know for certain whether this method is being used, Reaver is able to detect whether it is or not when the attack is launched:
```bash
reaver -c 6 -b 02:00:00:00:00:00 -i wlan4mon -vv
```
* `-c 6`: channel on which the access point is operating. 
* `-b 02:00:00:00:00:00`: MAC address of the access point.
* `-i wlan4mon`: name of the attacker’s interface.
* `-vv`: extended verbose mode, which provides more detailed output about what is happening during the attack.

**Attacker machine:**
<img width="878" height="841" alt="image" src="https://github.com/user-attachments/assets/e69fc29a-642a-4597-ad8c-39d7bb1d28d3" />
<img width="652" height="840" alt="image" src="https://github.com/user-attachments/assets/90e3fe4a-d588-4d3d-a0ab-dc2829f815e7" />
<img width="642" height="847" alt="image" src="https://github.com/user-attachments/assets/eb34bfaf-2abe-4c9e-89bc-72df469f6a0d" />
<img width="619" height="815" alt="image" src="https://github.com/user-attachments/assets/28483732-614a-443e-8962-cca2f16e9e69" />

**Access point (it can be seen that there is nothing referring to `02:00:00:00:04:00`, the attacker’s MAC):**
<img width="1257" height="302" alt="image" src="https://github.com/user-attachments/assets/a2d19383-db49-4a51-af68-e45ccd596dbc" />

However, after running the attack, something appears to fail: the access point does not seem able to correctly detect the necessary messages it must respond to after Reaver is launched in order to carry out the attack. This is because virtualization of wireless network cards through the `mac80211_hwsim` module does not provide an entirely faithful implementation of real wireless cards. As a result, some messages such as EAPOL (transport of messages over LAN networks) or M1-M8 (authentication communication between host and AP), which Reaver uses to perform its attacks, are not supported by the virtualization, making this attack unfeasible by this means. However, an example using a real access point and a USB Wi-Fi card will be shown (a typical setup for carrying out Wi-Fi attacks from a Kali Linux terminal). Specifically, the access point is a [`TP-LINK AC1200`](https://www.tp-link.com/es/home-networking/wifi-router/archer-c1200/):
<img width="590" height="443" alt="image" src="https://github.com/user-attachments/assets/4056eebd-fdd5-4195-a8c2-b76b2c16fded" />

Meanwhile, the wireless card, which will be used with a Kali Linux virtual machine, is an [`ALFA NETWORK AWUS036NHR`](https://www.amazon.es/Network-AWUS036NHR-150Mbit-adaptador-tarjeta/dp/B005ETA5K2):
<img width="771" height="1463" alt="image" src="https://github.com/user-attachments/assets/49e21ab2-6114-49bd-bcd3-667e9f4b5bc3" />

Once the [`Kali Linux`](https://www.osboxes.org/kali-linux/) virtual machine is started, the network card must be connected as follows:
<img width="1132" height="396" alt="image" src="https://github.com/user-attachments/assets/df583d4f-1979-4b83-b03c-e7f2ce1212a8" />

This way, `ifconfig` shows the name of the inserted interface, and all the steps seen above are repeated in order to perform the attack:
**Attacker machine:**
<img width="754" height="847" alt="image" src="https://github.com/user-attachments/assets/23b5c58f-d316-4f53-8537-295e7c90fa56" />
<img width="951" height="655" alt="image" src="https://github.com/user-attachments/assets/abfa5d6d-cfbe-4595-a989-1b67cbf78623" />

<img width="880" height="840" alt="image" src="https://github.com/user-attachments/assets/38526962-744d-4dd8-a97f-6f7ed155bd15" />
<img width="834" height="839" alt="image" src="https://github.com/user-attachments/assets/3395a0ee-64c7-4151-9b53-054a44db1201" />
<img width="790" height="859" alt="image" src="https://github.com/user-attachments/assets/b4ab7cce-12c1-4cdc-b7bb-fc1035e7431d" />
`...`
**Restart to avoid unlock on the access point:**
<img width="717" height="579" alt="image" src="https://github.com/user-attachments/assets/db05fdbe-c073-4f78-8e3a-01544545e345" />
**After restarting:**
<img width="746" height="419" alt="image" src="https://github.com/user-attachments/assets/21761629-e0f2-429f-ba22-41e4c0bb0d01" />
`...`
**After several restarts and finding the key:**
<img width="500" height="738" alt="image" src="https://github.com/user-attachments/assets/9e8cf606-5f0c-452b-92ae-ab1860faeb72" />

**Access point:**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/71f42b5b-2bf8-46d6-a4dc-91d8977d1bac" />

Once the attack is completed with physical interfaces, it can be observed that the key is obtained easily and that the use of a PIN is confirmed with the output `WPS PIN: Supported`. This demonstrates that WPS is one of the easiest methods to break, whether via PIN or via methods that require physical interaction or proximity (physical access to the access point is enough). Therefore, its use entails a major risk in exchange for a lot of convenience, which leads to a dilemma between usability and security. However, the only solution is not necessarily to choose one or the other; it can also be used in certain cases where and when it makes sense, without posing an excessively high risk.

However, nowadays it is not as easy to exploit as it seems, since the previous attack was only possible thanks to restarting WPS on the TP-LINK access point. This is because manufacturers of modern access points (roughly from 2015 onwards) began implementing WPS lockouts after several continuous attempts, ranging from a timeout to completely disabling all WPS activity on access points. Specifically, when it became fully locked, WPS had to be restarted in order to continue testing. This does not completely prevent the attack, but it allows administrators to see that someone is attempting to connect forcefully, which may cause them to reconsider whether they should reactivate it. This functionality is very good for stopping brute-force attacks, but only if it is handled properly. Next, the lab structure is used again to perform a custom brute-force attack, which is run while handling WPS lockouts both correctly and incorrectly.

First, the lab and the attacker machine are started in the same way as before:
```bash
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
Next, the [`wps_cracker.sh`]() script is run (it is recommended to analyze its behavior and verify that the network interface it uses is the one belonging to the attacker machine):
```bash
./wps_cracker.sh
```
Broadly speaking, this script attempts to run a brute-force-based attack that tries valid PINs through the `wps_reg` tool from `wpa_supplicant`, the same tool used by legitimate clients to connect via WPS. Specifically, this tool attempts to use WPS to obtain the WPA/WPA2 configuration in order to connect initially and remember that configuration (`wpa_supplicant.conf`) when trying to reconnect later. In addition, it makes use of the `wash` tool to check whether WPS has been locked on the access point due to repeated attempts, waiting until it is unlocked before trying the next key.

On the other hand, the script also uses the [`wpspin`](https://github.com/drygdryg/wpspin-nim) tool, which provides valid WPS PINs according to the MAC address of the access point. This is typical in hacking tasks because it makes it possible to intelligently reduce the search space in brute-force attacks, even making attacks that might initially seem unfeasible become possible.

Starting with the version that correctly handles WPS lockouts, it can be seen in the access point [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPS/internal/wireless/AP/Dockerfile) how the device acting as the access point uses the [`check_locked.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPS/internal/wireless/AP/check_locked.sh) script (it is recommended to analyze its contents, as well as verify that the interface it uses is the one belonging to the corresponding machine):

This script restarts the `hostapd` tool, which provides the Wi-Fi access point functionality, and also collects its log together with custom messages in `/var/log/hostapd-wps.log`. This prevents it from remaining permanently locked after a series of attempts, thus stopping the brute-force attack (the key it uses has been deliberately chosen from among the last ones to be tested). With the default use of this script when starting the machine and repeating the attack script from the Kali machine, the following result is obtained:
```bash
# Attacker machine
./wps_cracker.sh
```
<img width="1213" height="817" alt="image" src="https://github.com/user-attachments/assets/b8f4ae24-1321-4c46-bead-b6dec5901c33" />
<img width="1202" height="818" alt="image" src="https://github.com/user-attachments/assets/6ea8738d-68b4-4e6c-ba90-d4479a13b6a0" />
<img width="1206" height="771" alt="image" src="https://github.com/user-attachments/assets/a7a21b52-e83e-4896-a436-27efa9816319" />
<img width="1202" height="654" alt="image" src="https://github.com/user-attachments/assets/0e6f0ee0-2ae7-4d74-9a24-6d57d37f8381" />
<img width="1206" height="233" alt="image" src="https://github.com/user-attachments/assets/5810b1bc-3591-49c0-8ef0-f49cb9078754" />

As can be seen, a result similar to the one obtained with `reaver` and physical interfaces is achieved, which means discovering the WPS PIN of the access point, as well as obtaining the WPA/WPA2 configuration.
On the other hand, it is also possible to view what is happening on the access point, where the restart point can be seen along with how the WPS lockouts evolve:
```bash
# Real-time log
tail -f /var/log/hostapd-wps.log
# Full log
cat /var/log/hostapd-wps.log
```
<img width="1267" height="820" alt="image" src="https://github.com/user-attachments/assets/0deeaed3-9f3a-45af-8d5a-ebe06338ab97" />
<img width="1272" height="792" alt="image" src="https://github.com/user-attachments/assets/5e50d164-23cd-4083-8309-eaff0ad4e7e3" />
<img width="1268" height="817" alt="image" src="https://github.com/user-attachments/assets/5189f0d2-0997-4950-b674-05885c91eb8a" />
<img width="1282" height="839" alt="image" src="https://github.com/user-attachments/assets/a8bf82da-fe82-4dcc-8abb-b112d36afde1" />

However, if the key part of the [`check_locked.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/blob/WPS/internal/wireless/AP/check_locked.sh) script that restarts the access point is commented out, in order to manage WPS lockouts properly:
<img width="613" height="66" alt="image" src="https://github.com/user-attachments/assets/c2af9291-0a43-4adc-82c9-0d97fa15a317" />

the following result is obtained:
<img width="1213" height="842" alt="image" src="https://github.com/user-attachments/assets/57998c27-c83c-42e3-83ca-81839c608beb" />
<img width="1204" height="536" alt="image" src="https://github.com/user-attachments/assets/49116ae6-1558-4f6a-b6e8-02e0c0a4ac3d" />

<img width="1271" height="841" alt="image" src="https://github.com/user-attachments/assets/35c3eb3c-a873-496b-a850-54fb7b6452a7" />
<img width="1270" height="799" alt="image" src="https://github.com/user-attachments/assets/b0f047c7-7413-460c-809f-584b9e2cbf9f" />
<img width="1269" height="735" alt="image" src="https://github.com/user-attachments/assets/36df9fb9-3626-4ede-a580-7ba11e66d85e" />

Here it can be seen that the attack no longer succeeds, since a permanent WPS lockout is triggered on the access point after several PIN attempts (other shorter lockouts can also be seen). In this way, until an administrator restarts the access point, this attack will remain blocked. This shows the importance of proper management versus restarts without checks, which do not allow the attacker to be detected and let the attack continue after the machine acting as the Wi-Fi access point is restarted.

### Countermeasures and Recommendations
Therefore, it is advisable to avoid making access to buttons or NFC easy, and even to avoid these options altogether due to how dangerous they are. In addition, to mitigate their effects, it is recommended to use the latest versions of WPS, which include mitigations against these attacks, such as WPS lockouts after multiple failed attempts, as seen during the attack phase. However, as a general rule, it is recommended to disable any WPS method outside a controlled environment, paying special attention to devices that come with this technology enabled by default. A good way to use it is to activate it during short periods of time in which the administrator is aware of which clients are connecting at that moment, and ideally monitoring this activity (and even enabling some iptable that blocks any device making too many attempts if the device does not enforce WPS lockouts after multiple failed attempts by default).

`Reminder:` It is advisable to repeat the [attacks](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/Attacks) carried out after gaining access using the configuration from this chapter, in order to see that once inside, the security chosen on the access point becomes irrelevant, thus allowing the same results.

[`Previous lesson, cracking WPA/WPA2 PSK networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-PSK)
[`Next lesson, cracking WPA/WPA2 EAP networks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course-English/tree/WPA/WPA2-RADIUS)
