# WPS Cracking Lab
## Introducción
En este bloque se busca atacar una tecnología implementada para facilitar la conexión a los clientes WPS, la cual se suele usar en combinación con otros protocolos de seguridad como WPA, WPA2 o WPA3. Para ello, se sigue la misma metodología que en los ataques previos, viendo todos los detalles del protocolo, así como vulnerabilidades y contramedidas a los ataques ejecutados.

## Protocolo WPS
WPS fue introducido en 2006 como una capa adicional de configuración de los protocolos WPA/WPA2 PSK que facilita la conexión a los usuarios. Este tipo de configuración evita a dichos usuarios la introducción de la contraseña (PSK), permitiendo otras alternativas para el proceso de autenticación: [[39](https://ro.ecu.edu.au/ecuworks2012/146/)]
- PIN de 8 dígitos
- Pulsar un botón específico del punto de acceso
- Uso de tecnología NFC

### Vulnerabilidades
En el caso de usar los botones o NFC, la exposición del dispositivo al público puede suponer un grave problema de seguridad, ya que solo basta con tener acceso físico a dicho punto de acceso para poder conectarnos a la red como usuarios legítimos. Por otro lado, las opciones relacionadas con un PIN de corta longitud (8 dígitos) da paso a ataques de fuerza bruta. Donde destacan los ejecutados con herramientas como Reaver [[38](https://www.kali.org/tools/reaver/)], la cual simplemente requiere de tener Python instalado. [[39](https://ro.ecu.edu.au/ecuworks2012/146/)]

## Atacando WPS
Una vez nos encontramos en la rama respectiva a la versión WPS de la seguridad del punto de acceso, se debe lanzar el laboratorio y establecer conexión con la máquina Kali de igual forma que se hace en los capítulos previos:
```
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
Una vez dentro se procede nuevamente a activar el modo monitor en la interfaz inalámbrica del atacante (wlan4) con objeto de capturar paquetes que no van dirigidos a esta máquina. Esto se realiza en un primer instante con objeto de visualizar aquellos puntos de acceso que activan WPS, así como otros detalles como podría ser la versión de este protocolo:
```
airmon-ng start wlan4
```
`Recordatorio:` Esto puede generar una interfaz en modo monitor con igual nombre o alguno similar a `wlan4mon`, también revisar con `ifconfig` que la interfaz de la máquina atacante sea `wlan4`.

Con el modo monitor activo, ya se puede lanzar `airodump-ng` con el objetivo de visualizar aquellos dispositivos que activan WPS (usar opciones como `-c` para filtrar los resultados si se ve necesario):
```
airodump-ng --wps wlan4mon
```
<img width="927" height="179" alt="image" src="https://github.com/user-attachments/assets/59105bc4-089b-4929-8996-2b77aa0211be" />

Tras esto se visualiza que nuestro objetivo, la red con SSID `WPSnetwork`, está usando el protocolo WPS (posiblemente con PIN). Para verificar esta información también se puede usar la herramienta `wash`, la cual forma parte del paquete reaver que se usará para manifestar el ataque de fuerza bruta final:
```
wash -i wlan4mon
```
<img width="813" height="145" alt="image" src="https://github.com/user-attachments/assets/5726d5b3-5a32-4402-87d1-6d856382d4d5" />

`Nota:` También es necesario que la interfaz esté en modo monitor para esta herramienta, ya que necesita la capacidad de escuchar comunicaciones ajenas.

Una vez se confirma que la red `WPSnetwork` usa WPS, se puede proceder a usar la herramienta Reaver para lanzar el ataque de fuerza bruta que prueba todas las opciones del PIN de 8 dígitos que posiblemente tenga activo WPS. Aunque aún no sabemos a ciencia cierta que se esté usando este método, Reaver es capaz de detectar si se usa o no cuando se lanza el ataque:
```
reaver -c 6 -b 02:00:00:00:00:00 -i wlan4mon -vv
```
* `-c 6`: canal en el que trabaja el punto de acceso. 
* `-b 02:00:00:00:00:00`: dirección MAC del punto de acceso.
* `-i wlan4mon`: nombre de la interfaz del atacante.
* `-vv`: modo verbose extendido que detalla en mayor medida lo que está sucediendo mientras se realiza el ataque.

**Máquina del atacante:**
<img width="878" height="841" alt="image" src="https://github.com/user-attachments/assets/e69fc29a-642a-4597-ad8c-39d7bb1d28d3" />
<img width="652" height="840" alt="image" src="https://github.com/user-attachments/assets/90e3fe4a-d588-4d3d-a0ab-dc2829f815e7" />
<img width="642" height="847" alt="image" src="https://github.com/user-attachments/assets/eb34bfaf-2abe-4c9e-89bc-72df469f6a0d" />
<img width="619" height="815" alt="image" src="https://github.com/user-attachments/assets/28483732-614a-443e-8962-cca2f16e9e69" />

**Punto de acceso (se aprecia como no hay nada referente a `02:00:00:00:04:00`, la MAC del atacante):**
<img width="1257" height="302" alt="image" src="https://github.com/user-attachments/assets/a2d19383-db49-4a51-af68-e45ccd596dbc" />


Sin embargo, tras ejecutar el ataque vemos como algo falla, parece que el punto de acceso no es capaz de detectar correctamente los mensajes necesarios con los que debe contestar el punto de acceso tras lanzar reaver para poder ejecutar el ataque. Esto se debe a que la virtualización de las tarjetas de red inalámbricas mediante el módulo `mac80211_hwsim` no ofrecen una implementación completamente fiel a las tarjetas inalámbricas reales. De esta forma algunos mensajes como los EAPOL (transporte de mensajes mediante redes LAN) o M1-M8 (comunicación de autenticación entre host y AP) que usa reaver para realizar los ataques no son soportados por la virtualización, haciendo que este ataque no sea viable por este medio. Sin embargo, se mostrará un ejemplo un punto de acceso real y una tarjeta WiFi USB (típico para realizar ataques WiFi desde un terminal Kali Linux). En concreto, el punto de acceso es un [`TP-LINK AC1200`](https://www.tp-link.com/es/home-networking/wifi-router/archer-c1200/):
<img width="590" height="443" alt="image" src="https://github.com/user-attachments/assets/4056eebd-fdd5-4195-a8c2-b76b2c16fded" />

Mientras que la tarjeta inalámbrica, la cual se usará con una máquina virtual de Kali Linux, se trata de una [`ALFA NETWORK AWUS036NHR`](https://www.amazon.es/Network-AWUS036NHR-150Mbit-adaptador-tarjeta/dp/B005ETA5K2):
<img width="771" height="1463" alt="image" src="https://github.com/user-attachments/assets/49e21ab2-6114-49bd-bcd3-667e9f4b5bc3" />

Una vez se inicia la máquina virtual [`Kali Linux`](https://www.osboxes.org/kali-linux/) se debe conectar la tarjeta de red de la siguiente manera:
<img width="1132" height="396" alt="image" src="https://github.com/user-attachments/assets/df583d4f-1979-4b83-b03c-e7f2ce1212a8" />

De esta forma con `ifconfig` se visualiza el nombre de la interfaz introducida, repitiendo todos los pasos vistos anteriormente para realizar el ataque:
**Máquina del atacante:**
<img width="754" height="847" alt="image" src="https://github.com/user-attachments/assets/23b5c58f-d316-4f53-8537-295e7c90fa56" />
<img width="951" height="655" alt="image" src="https://github.com/user-attachments/assets/abfa5d6d-cfbe-4595-a989-1b67cbf78623" />

<img width="880" height="840" alt="image" src="https://github.com/user-attachments/assets/38526962-744d-4dd8-a97f-6f7ed155bd15" />
<img width="834" height="839" alt="image" src="https://github.com/user-attachments/assets/3395a0ee-64c7-4151-9b53-054a44db1201" />
<img width="790" height="859" alt="image" src="https://github.com/user-attachments/assets/b4ab7cce-12c1-4cdc-b7bb-fc1035e7431d" />
`...`
**Reinicio para evitar desbloqueo en el punto de acceso:**
<img width="717" height="579" alt="image" src="https://github.com/user-attachments/assets/db05fdbe-c073-4f78-8e3a-01544545e345" />
**Tras reiniciar:**
<img width="746" height="419" alt="image" src="https://github.com/user-attachments/assets/21761629-e0f2-429f-ba22-41e4c0bb0d01" />
`...`
**Tras varios reinicios y encontrar la clave:**
<img width="500" height="738" alt="image" src="https://github.com/user-attachments/assets/9e8cf606-5f0c-452b-92ae-ab1860faeb72" />

**Punto de acceso:**
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/71f42b5b-2bf8-46d6-a4dc-91d8977d1bac" />

Una vez se completa el ataque con las interfaces físicas se puede observar que se consigue fácilmente la clave, además, se confirma el uso de PIN con la salida `WPS PIN: Supported`. Con esto se demuestra que WPS es uno de los métodos más fáciles de romper, ya sea mediante PIN o los métodos que necesitan un accionamiento físico o por cercanía (basta con tener acceso físico al punto de acceso). Por tanto, su uso supone un gran riesgo a cambio de mucha comodidad, lo cual nos lleva a un dilema entre usabilidad y seguridad. Aunque no es la única solución elegir uno u otro, sino que puede usarse en determinados casos donde y cuando tenga sentido, sin suponer un riesgo demasiado alto.

Sin embargo, hoy en día no resulta tan fácil de explotar como parece, ya que el ataque anterior solo ha sido posible gracias a reiniciar WPS en el punto de acceso TP-LINK. Esto se debe a que los fabricantes de los puntos de acceso modernos (a partir de 2015 aproximadamente) empezaron a implementar bloqueos en WPS tras varios intentos continuados que van desde un tiempo de inactividad hasta cortar toda actividad de WPS en los puntos de acceso. En concreto, cuando se llegaba a bloquear por completo era necesario el reinicio de WPS para poder seguir haciendo pruebas. Esto no impide por completo el ataque, pero permite ver a los administradores que alguien intenta conectarse forzasamente, haciendo que se piensen si deben reactivarlo. Esta funcionalidad es muy buena para detener ataques de fuerza bruta, pero únicamente en el caso de manejarla adecuadamente. A continuación, se usa de nuevo la estructura que proporciona el laboratorio para realizar un ataque de fuerza bruta personalizado, el cual se ejecuta administrando tanto correcta, como incorrectamente los bloqueos WPS.

En primer lugar, se inicia el laboratorio y la máquina del atacante de la misma forma que se ha hecho hasta ahora:
```
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
A continuación, se ejecuta el script [`wps_cracker.sh`]() (se aconseja analizar su comportamiento y comprobar que la interfaz de red que utiliza es la de la máquina atacante):
```
./wps_cracker.sh
```
Este script en líneas generales intenta ejecutar un ataque basado en fuerza bruta, el cual prueba PINs válidos mediante la herramienta `wps_reg` de `wpa_supplicant`, la misma que se usa en los clientes legítimos para conectarlos mediante WPS. En concreto, esta herramienta trata de usar el WPS para obtener la configuración WPA/WPA2 para poder conectarse en primera instancia y recordar dicha configuración (`wpa_supplicant.conf`) cuando traten de volver a conectarse en nuevas ocasiones. Además, se hace uso de la herramienta `wash` para comprobar si se ha bloqueado WPS en el punto de acceso debido a los repetidos intentos, esperando hasta que este se desbloquee antes de probar la próxima clave.

Por otro lado, el script también hace uso de la herramienta [`wpspin`](https://github.com/drygdryg/wpspin-nim) que proporciona PINs válidos de WPS según la dirección MAC del punto de acceso. Esto es típico en labores de hacking ya que permite reducir de manera inteligente el espacio de búsqueda en ataques de fuerza bruta, haciendo incluso que ataques que a priori puedan parecer inviables, lleguen a ser posibles. 

Empezando por la versión que gestiona correctamente los bloqueos WPS, se aprecia en el [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPS/internal/wireless/AP/Dockerfile) de punto de acceso cómo el dispositivo que interpreta al punto de acceso usa el script [`check_locked.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPS/internal/wireless/AP/check_locked.sh) (se aconseja analizar su contenido, así como comprobar que la interfaz que utiliza es la de la máquina correspondiente):

Este script reinicia la herramienta `hostapd` que proporciona la funcionalidad de punto de acceso WiFi, además de recoger el log de este junto a mensajes personalizados en `/var/log/hostapd-wps.log`. Con esto se evita que se quede bloqueado permanentemente tras una serie de intentos, deteniendo así el ataque de fuerza bruta (la clave que usa ha sido escogida a drede entre las últimas que se prueban). Con el uso por defecto de este script al arrancar la máquina y repitiendo el script de ataque desde la máquina Kali, se obtiene el siguiente resultado:
```
# Máquina atacnate
./wps_cracker.sh
```
<img width="1213" height="817" alt="image" src="https://github.com/user-attachments/assets/b8f4ae24-1321-4c46-bead-b6dec5901c33" />
<img width="1202" height="818" alt="image" src="https://github.com/user-attachments/assets/6ea8738d-68b4-4e6c-ba90-d4479a13b6a0" />
<img width="1206" height="771" alt="image" src="https://github.com/user-attachments/assets/a7a21b52-e83e-4896-a436-27efa9816319" />
<img width="1202" height="654" alt="image" src="https://github.com/user-attachments/assets/0e6f0ee0-2ae7-4d74-9a24-6d57d37f8381" />
<img width="1206" height="233" alt="image" src="https://github.com/user-attachments/assets/5810b1bc-3591-49c0-8ef0-f49cb9078754" />

Como se aprecia, se obtiene un resultado parecido al conseguido con `reaver` y las interfaces físicas, lo cual supone encontrar el PIN WPS del punto de acceso, así como la obtención de la configuración WPA/WPA2. 
Por otro lado, también se puede visualizar lo que está sucediendo en el punto de acceso, donde se aprecia el punto de reinicio y cómo evolucionan los bloqueos WPS:
```
# Log en tiempo real
tail -f /var/log/hostapd-wps.log
# Log completo
cat /var/log/hostapd-wps.log
```
<img width="1267" height="820" alt="image" src="https://github.com/user-attachments/assets/0deeaed3-9f3a-45af-8d5a-ebe06338ab97" />
<img width="1272" height="792" alt="image" src="https://github.com/user-attachments/assets/5e50d164-23cd-4083-8309-eaff0ad4e7e3" />
<img width="1268" height="817" alt="image" src="https://github.com/user-attachments/assets/5189f0d2-0997-4950-b674-05885c91eb8a" />
<img width="1282" height="839" alt="image" src="https://github.com/user-attachments/assets/a8bf82da-fe82-4dcc-8abb-b112d36afde1" />

Sin embargo, si se comenta la parte clave del script [`check_locked.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPS/internal/wireless/AP/check_locked.sh) que reinicia el punto de acceso, para hacer un buen manejo de los bloqueos WPS:
<img width="613" height="66" alt="image" src="https://github.com/user-attachments/assets/c2af9291-0a43-4adc-82c9-0d97fa15a317" />

se obtiene el siguiente resultado:
<img width="1213" height="842" alt="image" src="https://github.com/user-attachments/assets/57998c27-c83c-42e3-83ca-81839c608beb" />
<img width="1204" height="536" alt="image" src="https://github.com/user-attachments/assets/49116ae6-1558-4f6a-b6e8-02e0c0a4ac3d" />

<img width="1271" height="841" alt="image" src="https://github.com/user-attachments/assets/35c3eb3c-a873-496b-a850-54fb7b6452a7" />
<img width="1270" height="799" alt="image" src="https://github.com/user-attachments/assets/b0f047c7-7413-460c-809f-584b9e2cbf9f" />
<img width="1269" height="735" alt="image" src="https://github.com/user-attachments/assets/36df9fb9-3626-4ede-a580-7ba11e66d85e" />

Aquí se aprecia como el ataque ya no tiene resultado, ya que se ejecuta un bloqueo permanente de WPS en el punto de acceso tras varios intentos de PIN (además se aprecian otros bloqueos de menor tiempo). De esta forma, hasta el momento que un administrador no reinicie el punto de acceso, este ataque se verá bloqueado. De esta forma se aprecia la importancia de una buena gestión frente a reinicios sin comprobaciones que no permiten detectar al atacante, dejando que su ataque siga tras reiniciar la máquina que actúa como punto de acceso WiFi.

### Contramedidas y Recomendaciones
De forma que es recomendable evitar facilitar el acceso a los botones o NFC, e incluso evitar directamente estas opciones debido a su gran peligrosidad. Además, para paliar sus efectos, se recomienda usar las últimas versiones de WPS, las cuales cuentan con mitigaciones a estos ataques, por ejemplo, con bloqueos de WPS tras múltiples intentos fallidos, tal y como se ha visto en la fase de ataque. Sin embargo, por norma general se recomienda deshabilitar cualquier método WPS fuera de un entrono controlado, poniendo especial atención en aquellos dispositivos que traen configurada esta tecnología por defecto. Una buena opción de uso es activarlo durante pequeños periodos de tiempo en los que el administrador sea consciente de los clientes que se conectan en ese momento y monitoreando esto a ser posible (e incluso activar alguna iptable que bloquee algún dispositivo que lanza demasiados intentos si el dispositivo no hace bloqueos de WPS tras múltiples intentos fallidos por defecto). 

`Recordatorio: ` Se aconseja repetir los [ataques](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks) realizados tras conseguir acceso con la configuración de este capítulo para ver que una vez dentro la seguridad elegida en el punto de acceso es irelevante, permitiendo así los mismos resultados. 

[`Lección anterior, cracking de redes WPA/WPA2 PSK`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-PSK)
[`Siguiente lección, cracking de redes WPA/WPA2 EAP`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS)
