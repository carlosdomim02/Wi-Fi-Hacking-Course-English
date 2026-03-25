# WPA/WPA2 PSK Cracking Lab
## Introducción

Ahora es turno de continuar haciendo pruebas de ataque con la siguiente versión del protocolo de seguridad que surge después de que la IEEE se diese cuenta de sus fallas y propusiese dos algoritmos para sustituir al antiguo WEP: WPA de forma temporal y WPA2 como versión definitiva. Además, se seguirá la misma metodología que en el ataque a [WEP](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WEP), comentando primero el funcionamiento del protocolo WPA/WPA2 PSK, seguido del ataque como tal, así como las respectivas recomendaciones y contramedidas.

## Protocolos de Seguridad WPA/WPA2 PSK

Debido a las múltiples imperfecciones que hacían débil al protocolo WEP, en 2003 surge un mecanismo de seguridad conocido como WPA. Este protocolo tiene como objetivo paliar los defectos de WEP mientras se crea uno de mayor calidad, que conoceremos más tarde en 2004 como WPA2. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

A pesar de ser una solución intermedia, WPA supone una gran mejora de seguridad respecto a su predecesor, WEP: [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]
- **Cifrado más robusto:**  
  WPA pasa a implementar claves precompartidas de mayor longitud (256 bits), así como IVs que doblan la longitud previa de WEP (48 bits frente a los 24 anteriores). Además existe la posibilidad de usar otro mecanismo de cifrado de las comunicaciones: el algoritmo de cifrado por bloques AES (robusto a día de hoy) con claves de 256 bits.

- **Control de integridad mejorado:**  
  Otro gran punto débil de WEP era el uso de CRC para proteger la integridad de las comunicaciones, mecanismo débil. En su lugar WPA introduce el uso de MIC (Message Integrity Code). La principal diferencia entre MIC y un sencillo hash o MAC es que MIC ayuda a detectar y prevenir alteraciones de forma más eficaz.

- **Uso de claves temporales:**  
  WPA introduce el uso de claves temporales para cifrar los paquetes; cada paquete usa una nueva clave generada a partir de la clave maestra establecida al iniciar la comunicación (esta, a su vez, se genera a partir de la clave precompartida (PSK) y otros parámetros que se envían en texto plano). La parte negativa es que, en sus modos antiguos, este protocolo seguía usando RC4/MIC en la transmisión de algunos paquetes.

- **Soporte para servidor de autenticación:**  
  Se introduce la capacidad de conectar un punto de acceso a un servidor de autenticación, evitando el uso exclusivo de claves precompartidas. Esta variante está pensada para organizaciones, usando credenciales por usuario/contraseña o certificados.

Como ya se ha mencionado anteriormente, WPA introduce la capacidad de usar AES como algoritmo de cifrado, pero no obliga a ello. De esta forma, la principal diferencia entre WPA y su sucesor, WPA2, reside en que este segundo obliga a utilizar el estándar AES (más robusto que RC4) en el proceso de cifrado. Mientras que TKIP de WPA usa RC4 y MIC para proteger la confidencialidad e integridad, WPA2 pasa al uso obligado de CCMP que implementa los algoritmos AES y CBC-MAC. 

El protocolo CCMP ahora se encargará de generar claves temporales de una manera más segura que TKIP al utilizar el algoritmo AES en lugar de RC4. Además, sustituye la comprobación de la integridad MIC por CBC-MAC, un algoritmo que también resulta más robusto.

Por otro lado, gracias a la introducción del soporte para la autenticación mediante un servidor destinado para esta tarea, se destacan dos tipos de protocolo, y por tanto, de ataque. Los relativos a los protocolos WPA/WPA2 PSK (de clave compartida, los tradicionales) y los relativos a los protocolos WPA/WPA2 Enterprise (usan un servidor de autenticación).

Centrando la atención en las versiones tradicionales (PSK), ambas son atacadas usando una misma vulnerabilidad relacionada con el proceso de autenticación y generación de la clave maestra, protocolo conocido como *4-way handshake*:  
![image](https://github.com/user-attachments/assets/e03f855a-320c-4ed8-af46-716354a7cc02)


### Vulnerabilidades 

Los ataques suelen basarse en la recolección de este proceso para obtener todos los datos usados en la generación de la clave maestra (Primary Master Key, NONCE, etc.). Una vez se conocen todos los datos de generación de la clave maestra desde la que partirán los protocolos TKIP o CCMP, se suelen utilizar ataques de diccionario. Estos ataques prueban claves precompartidas típicas junto con los datos recabados con la intención de generar claves maestras válidas. De esta forma, si se logra dar con la clave maestra que realmente se está usando, no solo se consiguen leer los paquetes intercambiados con ese usuario legítimo, sino que se podría llegar a obtener la clave precompartida (PSK) que nos da acceso a la red. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

Otro ataque común es el conocido como ataque de de-autenticación, el cual consiste más bien en un complemento de los ataques anteriores. Dicho ataque fuerza la desconexión de alguno de los clientes legítimos, haciendo que se vuelva a conectar instantáneamente y genere un nuevo 4-way handshake que se podrá capturar. Esto es realmente útil si la red contiene pocos clientes, ya que podría ser muy largo el tiempo de espera hasta que un nuevo cliente se conecte y genere esta secuencia de paquetes. [[36](https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5601275)]

A continuación se usarán ambos en un proceso de atacar cualquiera de los dos protocolos. Como ambos tienen los mismos vectores de ataque solo se mostrará como atacar al más robusto, WPA2, el cual está configurado por defecto como punto de acceso en Hostapd (en el AP). En caso de querer cambiarlo descomentar la opción de [`Dockerfile`]() de AP que copia la configuración para WPA y comentar la de WPA2:


## Atacando WPA/WPA2 PSK
Tras configurar la versión de WPA deseada para el ataque se debe comenzar lanzando el entorno (asegurándose de estar en esta rama) y estableciendo conexión con la máquina Kali Linux (hay que esperar a que se configure todo previamente por seguridad):
```
sudo ./launch.sh
docker-compose exec attacker-1 bash 
```
Una vez dentro se procede nuevamente a activar el modo monitor en la interfaz inalámbrica del atacante (wlan4) con objeto de capturar paquetes que no van dirigidos a esta máquina. Esto se realiza con el objetivo de capturar los procesos *4-way handshake* que contienen los detalles para establecer la comunicación y las claves, tal y como se mencionó anteriormente.
```
airmon-ng start wlan4
```
`Recordatorio:` Esto puede generar una interfaz en modo monitor con igual nombre o alguno similar a `wlan4mon`, también revisar con `ifconfig` que la interfaz de la máquina atacante sea `wlan4`.

Con el modo monitor activo, ya se puede lanzar `airodump-ng` con el objetivo de visualizar los detalles del punto de acceso que se va a vulnerar:
```
airodump-ng wlan4mon
```
![image](https://github.com/user-attachments/assets/4e43bb6e-0c12-4743-9656-97f7f43e0075)

Una vez localizado el punto de acceso objetivo, `WPAnetwork`, la idea es rescatar un proceso de *4-way handshake* de un cliente legítimo que inicie su conexión con el punto de acceso. Para ello, en primer lugar, se puede usar este mismo comando optimizándolo para que solamente escuche las trazas relacionadas con dicho punto de acceso: [[37](https://www.aircrack-ng.org/doku.php?id=cracking_wpa)]
```
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon
```
* `-c 6`: canal en el que trabaja el punto de acceso.
* `--bssid 02:00:00:00:00:00`: dirección MAC del punto de acceso.
* `-w wpa-wpa2`: nombre (sin extensión) de los ficheros donde se almacenarán los paquetes capturados.
* `wlan4mon`: nombre de la interfaz del atacante.
![image](https://github.com/user-attachments/assets/8556f7c8-c786-4b4e-bec8-4473200427b7)

`Recordatorio:` Este proceso genera varios ficheros en los que almacena los paquetes capturados, destacando el terminado en `.cap` que almacena los paquetes en un formato pensado para que lo lean otras herramientas como `wireshark` o `aircrack-ng`.

En la parte de abajo se ven los clientes activos que envían paquetes al punto de acceso, de tal forma que necesitamos capturar una negociación de clave (4-wayhandshake) de uno de ellos o de otro dispositivo que se vuelva a conectar (esto es más posible). Normalmente estos ataques se hacen en redes con gran volumen de clientes donde es habitual que alguno se desconecte y se vuelva a conectar o que llegue un nuevo cliente legítimo. Sin embargo, si solo esperamos a que esto pase, en algún caso puede requerir una larga espera hasta ver un mensaje de tipo `EAPOL` o `WPA handshake` que indique la captura del proceso de autenticación/negociación de clave.

Para poder acelerar este proceso lo ideal sería forzar a alguno de los clientes actuales a desconectarse, confiando en que tengan un método de conexión automática al punto de acceso que les haga volver a conectarse de nuevo, generando el deseado *4-way handshake*. Para ello se puede usar de nuevo la herramienta `aireplay-ng` con 
```
# En otra terminal (se puede realizar con otras MAC víctima)
docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon
```
- `-0`: deauthentication (ataque que fuerza deautenticaciones).
- `1`: número de mensajes de deautenticación enviados.
- `-a 02:00:00:00:00:00`: dirección MAC del punto de acceso.
- `-c 02:00:00:00:02:00`: dirección MAC del cliente al que deautenticar (si no se pone lo lanza para todos los clientes).
- `wlan4mon`: is the interface name.

De esta forma, tras varios intentos de deautenticación o simplemente tras esperar sin esta aceleración, se detecta el mensaje que indica la captura del proceso de negociación de la clave compartida que usarán cliente y punto de acceso:
![image](https://github.com/user-attachments/assets/ad332206-8d70-48e6-b799-60073a6c3bd5)

Este proceso no solo establece la clave que se usará para el cifrado, sino que también usa en este la clave maestra o clave precompartida, la cual da acceso a la red, es decir, es la clave que pide el punto de acceso WiFi cuando alguien intenta conectarse a él. De esta forma, mediante un proceso de fuerza bruta con diccionario (sino puede ser muy largo este proceso, en especial con claves robustas) se puede rescatar esta clave precompartida con los datos recopilados, así como la clave con la que el cliente al que pertenece este proceso cifra los datos compartidos con el punto de acceso o viceversa. Para poder hacer esto se utiliza de nuevo el comando `aircrack-ng` con las siguientes opciones:
```
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```
- `/usr/share/wordlists/rockyou.txt`: diccionario de claves (conviene usar ruta absoluta, en este caso se usa una ruta y nombre típicos).
- `-b 02:00:00:00:00:00`: dirección MAC del punto de acceso.
- `wpa-wpa2*.cap`: usar todos los archivos .cap que comienzan con el nombre "wpa-wpa2" (si se hacen varios `airodump-ng` con `-w wpa-wpa2` se generarán archivos wpa-wpa2N.extension).

Como se aprecia, este comando también necesita de un diccionario o lista de claves que pueda probar. Aquí es típico probar tanto aquellas listas recopiladas de Internet con claves típicas en general, como aquellas con claves por defecto de alguna compañía telefónica. Por tanto, se recomienda elegir aquella que se ajuste mejor a las necesidades de cada ataque. En el caso de este curso se usa una lista de Kali Linux con claves típicas que suele ser usada en combinación con `aircrack-ng` para acelerar el ataque:
- `rockyou.txt`: se trata de una lista típica de [`Kali Linux`](https://www.kali.org/tools/wordlists/).

Tras esto se obtiene la clave deseada, lo cual da acceso a la red interna (en específico a la parte WLAN), lo cual tiene graves consecuencias como se vio en el capítulo [anterior](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks):
![image](https://github.com/user-attachments/assets/f29039c0-92b8-4106-bd58-c441fc656040)

`Nota:` Puede que algún paquete del proceso 4-wayhandshake no haya sido capturado correctamente y que esto genere un error al ejecutar esta última parte del ataque, lo cual provoca que haya que repetir la captura deseando tener más suerte.

Por último, se recomienda repetir el ataque modificando el fichero [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-PSK/internal/wireless/AP/Dockerfile) para cambiar la configuración actual que usa el protocolo WPA2 (el más robusto de los dos) comentando la línea que hace referencia al archivo `hostapd.conf` con la versión WPA2 y descomentando la referente a WPA (y relanzar el laboratorio para fijar esta modificación). Esto se hace con el objetivo de probar que el vector de ataque al que se someten ambas versiones es exactamente el mismo:
![image](https://github.com/user-attachments/assets/652e2717-9ef0-45bc-ac37-54dffd6d83ac)

```
# Parar y relanzar el laboratorio
sudo ./stop.sh
sudo ./launch.sh
```

### Contramedidas y recomendaciones
La principal contramedida para evitar este tipo de problemas si se quiere seguir usando WPA/WAP2 es usar una contraseña robusta lo más larga posible (63 caracteres como máximo), por ejemplo:
```
X4r!tP7uNv#eLj29qWbR@KmZ8Yx&cDf9G3hTs%uQpL$JaMk0VbnEzHdCrL#oWy
```
Esto hace que los ataques de fuerza bruta sean demasiado costosos, incluso con computadores de alta potencia, llegando a necesitar años para romperla. También sería ideal cambiarla de vez en cuando, aunque sea una medida algo menos práctica. Si se repite el ataque con esta clave es necesario modificar [`internal/wireless/AP/hostapd-WPA.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA.conf) o [`internal/wireless/AP/hostapd-WPA2.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-PSK/internal/wireless/AP/hostapd-WPA2.conf) (según la versión usada) para cambiar esta contraseña en el punto de acceso, así como en los [`internal/wireless/client12/wpa_supplicant.conf
`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-PSK/internal/wireless/client12/wpa_supplicant.conf)/[`internal/wireless/client3/wpa_supplicant.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/WPA/WPA2-PSK/internal/wireless/client3/wpa_supplicant.conf)) de los respectivos clientes necesarios para generar los *hand shakes* y finalmente relanzar el laboratorio. De esta forma, se puede apreciar que la lista ya no contiene esta contraseña y, por tanto, no puede encontrar la clave del punto de acceso:
![image](https://github.com/user-attachments/assets/27f4bc05-99bd-4657-831e-5bd267923ee7)

```
docker-compose exec attacker-1 bash
airmon-ng start wlan4
airodump-ng wlan4mon
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wpa-wpa2 wlan4mon

# En otra terminal
docker-compose exec attacker-1 bash
aireplay-ng -0 1 -a 02:00:00:00:00:00 -c 02:00:00:00:02:00 wlan4mon

# Tras obtener el handshake
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 02:00:00:00:00:00 wpa-wpa2*.cap
```
![image](https://github.com/user-attachments/assets/85543419-8925-456d-b451-5244e7edf712)
![image](https://github.com/user-attachments/assets/92d4c4c9-7e86-452f-ba03-17c40ebb9fc6)
<img width="698" height="476" alt="image" src="https://github.com/user-attachments/assets/ac6ccf13-e848-410b-9277-365434786feb" />

Pero para que esto sea realmente eficaz hay que asegurarse también de que la clave no esté en este tipo de listas o no contenga información personal fácilmente identificable por los atacantes. Por otro lado, se podría considerar la actualización a otros protocolos de seguridad como las versiones Enterprise que se verán a continuación (especialmente pensadas para corporaciones) o WPA3, la versión más actual y robusta de este protocolo.

`Recordatorio: ` Se aconseja repetir los [ataques](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks) realizados tras conseguir acceso con la configuración de este capítulo para ver que una vez dentro la seguridad elegida en el punto de acceso es irelevante, permitiendo así los mismos resultados. 

[`Lección anterior, ataques tras conseguir acceso`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks)
[`Siguiente lección, cracking de redes WPS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPS)
