# Configuración del Laboratorio

Durante el desarrollo de esta sección (rama) se explicará en detalle cómo se ha creado el laboratorio y las peculiaridades de este. Aquí se detallará tanto la composición de los ficheros de configuración generales —como pueden ser el archivo [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/docker-compose.yml), [`launch.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/launch.sh) o [`stop.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/stop.sh)— como cada uno de los archivos que componen las distintas máquinas descritas en la [introducción](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course). Sin embargo, primero se deben conocer todas las tecnologías usadas.

## Tecnologías empleadas

A continuación se explican detalles que se deben tener en cuenta para poder comprender el funcionamiento real del laboratorio, desde las herramientas usadas para la simulación del entorno hasta algunos servicios de interés para conectar o proteger los distintos componentes de dicho entorno.

### Docker

Docker consiste en una herramienta de código abierto administrada por la compañía Docker Inc., la cual tiene como principal objetivo el empaquetado de aplicaciones y su fácil despliegue tanto en entornos locales como en la nube [[1](https://learn.microsoft.com/es-es/dotnet/architecture/microservices/container-docker-introduction/docker-defined)]. Esta tecnología se basa en la ejecución de contenedores, unos componentes estandarizados y ejecutables que combinan el código de la aplicación que se desea empaquetar junto a todas sus dependencias (tanto de sistema operativo como de otras tecnologías). Esto hace que las aplicaciones ejecutadas con estos contenedores solo contengan lo mínimo necesario para su ejecución, haciéndolas muy portables (pueden ejecutarse casi en cualquier entorno) y eficientes. [[2](https://www.ibm.com/es-es/think/topics/docker)]

Los contenedores son posibles gracias a ciertas capacidades del kernel de Linux que permiten ejecutar procesos de forma aislada con la ayuda de los namespaces. Estos envuelven un recurso global del sistema (como puede ser un montaje del sistema de archivos, una interfaz de red, un nombre de host, etc.) en una abstracción que hace creer a los procesos dentro de este namespace que tienen su propia instancia aislada del recurso global, llegando a ser invisible incluso para el resto de procesos externos a este namespace. De esta forma, `/proc/<PID>/ns/` indica los namespaces de los que un proceso es miembro, mientras que `/var/run/netns/` representa un directorio donde se guardan los namespaces de las interfaces de red, haciendo posible que estas sean movidas a un proceso específico. [[3](https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/what-namespaces-are-setting-limits-for-applications)]

Con todo esto, se puede lograr una virtualización ligera que permite la ejecución de aplicaciones con tan solo las dependencias necesarias, consiguiendo así una gran ventaja sobre las máquinas virtuales tradicionales (MVs), las cuales conllevan una mayor sobrecarga debido a la obligatoriedad de instalar y ejecutar sistemas completos. Más concretamente, las ventajas respecto a las máquinas virtuales tradicionales son las siguientes: [[2](https://www.ibm.com/es-es/think/topics/docker)]

- **Menor peso:** Los contenedores Docker solo portan la tecnología huésped mínima necesaria, junto a las dependencias indispensables. Además, no necesitan una máquina virtual completa ni un hypervisor que haga de intermediario entre el contenedor y el sistema anfitrión. Basta con el Docker Engine, una tecnología de función similar a un hypervisor, pero mucho menos pesada, ya que actúa como un proceso demonio. La propia ejecución del contenedor se representa como un proceso más en la máquina host, sin requerir una máquina virtual completa.
- **Mayor portabilidad y productividad:** A diferencia de las MVs, los contenedores parten de una imagen que se escribe una única vez y se puede distribuir fácilmente entre diferentes sistemas, siendo independientes del entorno en el que se ejecutan.
- **Mayor eficiencia y escalabilidad:** En especial en los sistemas en la nube, se tiende al uso de contenerización para ejecutar varias instancias de una misma aplicación rápidamente, gracias a la mayor velocidad de arranque/apagado de los contenedores y el uso reducido de recursos.

![image](https://github.com/user-attachments/assets/02ccb8b7-62d4-4470-bce2-d64be76bc97f)

Debido a todas estas ventajas respecto a las MVs, se ha escogido esta tecnología para crear el laboratorio que utilizará el curso. De esta forma, se pueden crear fácilmente una serie de "mini máquinas virtuales" personalizadas para simular la red de una pequeña empresa o un hogar. Al tratarse de una virtualización poco pesada y eficiente, el laboratorio permitirá un mayor número de máquinas y una amplia personalización.

Para entender mejor cómo funcionan los contenedores, se deben entender primero las conocidas como imágenes. Un contenedor es una imagen en ejecución: la imagen es la plantilla que usa Docker Engine para ejecutar las instrucciones necesarias para lanzar un contenedor. Las imágenes Docker almacenan las dependencias junto al código de la aplicación o aplicaciones que ejecutan.

Docker no es la única tecnología de contenerización, aunque sí resulta la más popular. Otras opciones como LXC (contenedores nativos del kernel de Linux) son más tediosas de usar. En cambio, Docker facilita la creación, envío y control de versiones de imágenes (repositorios tipo Docker Hub). Docker parte del kernel de Linux, pero puede ejecutarse en Windows o macOS gracias a Docker Desktop, que usa una virtualización ligera (WSL 2) para proporcionar las características necesarias del kernel. [[5](https://docs.docker.com/desktop/setup/install/windows-install/)]

#### Dockerfile

Docker facilita la creación de imágenes a través de especificaciones en ficheros Dockerfile, una de las opciones más populares. Los archivos Dockerfile son ficheros de texto que contienen las instrucciones necesarias para que Docker Engine cree las imágenes mediante `docker build`. [[6](https://docs.docker.com/build/concepts/dockerfile/)]

Normalmente estos ficheros parten de una imagen ya existente (para aprovechar la base mínima) y luego ejecutan una serie de instrucciones que permiten su personalización. Finalmente especifican un comando por defecto que se ejecuta cuando se lanza el contenedor. Con esto, Docker Engine crea una imagen Docker aplicando las instrucciones sobre la imagen base, y el resultado es un fichero de solo lectura que `docker run` usa para lanzar el contenedor.

```
# Ejemplo de fichero Dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# install app dependencies
RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip install flask==3.0.*

# install app
COPY hello.py /

# final configuration
ENV FLASK_APP=hello
EXPOSE 8000
CMD ["flask", "run", "--host", "0.0.0.0", "--port", "8000"]
```

#### Docker-compose

En entornos multicontenedor —donde se desean lanzar varias imágenes Docker a ejecución— puede complicarse la administración de los distintos contenedores. Por ello, existe una herramienta que facilita la construcción (`docker-compose build`) y la ejecución (`docker-compose up`) de entornos compuestos por múltiples contenedores Docker, haciendo sencillas labores como lanzar redes, servicios o usar volúmenes (directorios y/o ficheros) compartidos entre el host y el contenedor. Todo esto se consigue mediante la especificación de un fichero de configuración `YAML` (comúnmente `docker-compose.yml`), en el cual se indican los distintos servicios que se desean lanzar y las imágenes de las que parten, junto a opciones de configuración como las redes a las que se incorporan o el orden en el que se lanzan —respetando dependencias—. De esta forma, se consigue una administracción más sencilla y eficiente de los servicios ejecutados. [[7](https://docs.docker.com/compose/intro/compose-application-model/)]


```
# Ejemplo de fichero docker-compose.yml
services:
  frontend:
    image: example/webapp
    ports:
      - "443:8043"
    networks:
      - front-tier
      - back-tier
    configs:
      - httpd-config
    secrets:
      - server-certificate

  backend:
    image: example/database
    volumes:
      - db-data:/etc/data
    networks:
      - back-tier

volumes:
  db-data:
    driver: flocker
    driver_opts:
      size: "10GiB"

configs:
  httpd-config:
    external: true

secrets:
  server-certificate:
    external: true

networks:
  # The presence of these objects is sufficient to define them
  front-tier: {}
  back-tier: {}
```

Debido a todas estas ventajas, es una tecnología muy usada en aplicaciones con arquitectura de microservicios. Sin embargo, el entorno que representa el laboratorio montado para entrenar las habilidades de ataque a redes WiFi se beneficia también de estas ventajas al seguir una arquitectura que se puede asimilar a la de microservicios [[8](https://anderfernandez.com/blog/tutorial-docker-compose/)]. Múltiples máquinas que se comunican entre sí para lograr una labor común: la ejecución de un entorno de pruebas. De esta forma, estos contenedores presentan un cierto grado de aislamiento al solo ser capaces de comunicarse entre sí según lo especificado entre los Dockerfile que crean las imágenes y el fichero `docker-compose.yml` que lanza el entorno, permitiendo un control sobre el grado de comunicación de los distintos contenedores que entran en juego. Además, se permite la conexión individual a cada una de las máquinas simuladas en el entorno (`docker-compose exec`), lo cual facilita la visión de un atacante que solo conoce su máquina a priori.

### Firewall
![image](https://github.com/user-attachments/assets/587b710e-e50f-49fa-b4ff-c19867ca9cdb)

En la construcción del laboratorio se opta por obtener una infraestructura realista que, a pesar de no tener el mayor nivel de seguridad existente, refleje un nivel lo suficientemente alto como para asemejarse al mundo real. Por ello, se implementa una de las medidas de seguridad más conocidas y eficaces: un firewall. Se trata de un dispositivo —hardware o software— capaz de filtrar paquetes con el principal objetivo de prevenir accesos ilegítimos; sin embargo, también debe facilitar y administrar la comunicación entre dispositivos de confianza. Las principales amenazas que tratan de evitar son las siguientes: [[9](https://www.incibe.es/ciudadania/tematicas/configuraciones-dispositivos/cortafuegos)]
- Accesos no autorizados: evitan tráfico de fuentes no confiables.
- Propagación de malware: detectan tráfico malicioso que posiblemente porta malware, bloqueándolo para evitar contagios.
- Denegación de servicios (DoS): pueden detectar flujos masivos de datos y bloquearlos.
- Protección contra vulnerabilidades conocidas: reconocen tráfico malintencionado que intenta explotar vulnerabilidades.

Existen distintos tipos de firewalls según el sistema que se desea proteger: [[10](https://www.paloaltonetworks.com/cyberpedia/types-of-firewalls)]
- **Firewalls de red:** ubicados en la frontera entre redes —separan redes de confianza de las que no lo son— y aplican reglas de tráfico. Su objetivo principal es monitorear, controlar y decidir el tráfico al cual le da el visto bueno (o no) para pasar hacia la red de confianza. Normalmente este tipo de firewalls funciona con reglas que indican el tráfico que se deja pasar o no, pudiendo incluso realizar otras funcionalidades como el registro de paquetes.
  ![image](https://github.com/user-attachments/assets/7c71fbc6-9a77-4804-9ad4-b0a1fac6dcba)
- **Firewalls basados en el host:** software instalado en el dispositivo a proteger, filtrando únicamente el tráfico de dicha máquina (de entrada, salida o que lo atraviesa). Se centra en detectar contenido malicioso, software malicioso u otras actividades maliciosas destinadas a infiltrarse en el sistema protegido. Pueden ser especialmente interesantes en combinación con los cortafuegos de perímetro anteriormente vistos, ya que ofrece una segunda capa de protección en dispositivos individuales sumada a la ya existente ofrecida por la propia red (por su firewall perimetral). 
  ![image](https://github.com/user-attachments/assets/45a7375f-c505-4dc7-877a-caaa076a4527)

Para este laboratorio se usa principalmente un firewall de red que limita el tráfico entre la red de confianza (interna y de servidores) y la red externa. En algunos hosts se utiliza un cortafuegos software individual para añadir funcionalidades —por ejemplo, permitir tráfico concreto, pero manteniendo un cierto control que solo permita el tráfico legítimo—. Además, se pueden considerar otro tipo de clasificaciones de estos dispositivos, como la tecnología usada para lograr su objetivo. En este caso, se centra la mirada en la única que se usa durante el laboratorio, el filtrado de paquetes:

![image](https://github.com/user-attachments/assets/085d9818-2e40-452d-afb4-a7eec41b6d06)

Como su propio nombre indica, el filtrado de paquetes regula el tráfico entre redes gracias a reglas predefinidas que expresan patrones a aceptar o rechazar. Estas reglas pueden declarar atributos como IPs (origen/destino), puertos o protocolos que usan los paquetes trasmitidos para definir que tráfico dejan pasar y cual no. Aunque lo más común es definir reglas estáticas, existen mecanismos para crear o destruir reglas de manera dinámica —adaptando las reglas en tiempo real según el contexto y tráfico actual—. Además, se debe tener en cuenta si es *stateless* (analiza paquetes de forma individual) o *stateful* (tiene en cuenta conexiones previas). [[10](https://www.paloaltonetworks.com/cyberpedia/types-of-firewalls)] ara este laboratorio se ha escogido un firewall estático sin estado (en la maypría de casos, aunque existe alguna regla con estado para actuar sobre la respuesta de una petición), ya que es suficiente para crear una estructura DMZ realista.

#### DMZ
Para construir un entorno realista, el cual pueda asemejarse al de una empresa real, se ha optado por crear una DMZ o zona desmilitarizada. Se trata de una red aislada dentro de la red interna de la organización, donde se encuentran exclusivamente aquellos dispositivos que ofrecen servicios accesibles desde Internet (por ejemplo, un servidor web o de correo). Esta partición suele implicar un mayor nivel de protección en la red interna que en la red de servidores —esta última debe ser accesible desde el exterior—. Normalmente la red interna busca un nivel de protección alto, impidiendo cualquier tráfico entrante que no provenga de una conexión iniciada por un dispositivo interno a esta red. Además, el tráfico entre las redes (interna, DMZ y externa) es monitoreado y controlado por un firewall. [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)]
![image](https://github.com/user-attachments/assets/e9aafaab-6ce4-40c8-9158-4f68a9e5e2ee)

Este firewall es el encargado de controlar el tráfico entre las redes vistas, de tal forma que normalmente restringe en mayor medida a la red interna (no dejando iniciar conexiones desde fuera de esta, ya sea desde la red externa o desde la DMZ) que a aquella encargada ubicar los servidores accesibles desde Internet (normalmente también accesibles desde la red interna, pero no a la inversa). Esta separación se debe a que los servidores que son accesibles desde Internet son más susceptibles a sufrir un ataque que pueda comprometer su seguridad. Así, si un ciberdelincuente comprometiera un servidor de la DMZ, seguiría siendo complicado acceder a la red local gracias al filtrado. [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)]
![image](https://github.com/user-attachments/assets/93909e2c-d185-4ee1-a7aa-faeb89981bfb)
![image](https://github.com/user-attachments/assets/7fb9e819-baf3-4fe5-803b-c381a661c970)

Por otro lado, existe otra forma de construir este tipo de estructura, el uso de un doble firewall con el objetivo de que uno primero (el que hace contacto directo con la red externa y la DMZ) sea el encargado de establecer las reglas que protegen la DMZ (menos restrictivas). Mientras, otro segundo (que hace contacto con el anterior y la red interna) se encarga de establecer reglas más restrictivas para proteger la red interna. [[11](https://www.incibe.es/empresas/blog/dmz-y-te-puede-ayudar-proteger-tu-empresa)] Este tipo de configuración puede proporcionar una estructura más robusta y modular, sin embargo, en el laboratorio se opta por el uso de un único cortafuegos al tratarse de una estructura que no tiene un gran tamaño, para la cual es suficiente un único dispositivo de estas características.
![image](https://github.com/user-attachments/assets/28e804c6-5b6a-439d-89e8-3f8200d17a8d)

#### iptables
Una manera típica y flexible de integrar reglas de firewall en máquinas con kernel de Linux coniste en usar iptables. Esta herramienta basa su funcionamiento en Netfilter —un poderoso subsistema de redes del Kernel de Linux— el cual ofrece capacidades para el filtrado de paquetes (con y sin estado), así como para otros servicios —por ejemplo, NAT o enmascaramiento de IP—. De esta forma, iptables actuará como interfaz de control sobre Netfilter, pudiendo crear o destruir reglas de firewall mediante el uso de comandos de Shell. [[12](https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/6/html/security_guide/sect-security_guide-firewalls#sect-Security_Guide-Firewalls-Netfilter_and_IPTables)]

### Honeypot
Para seguir con la dinámica de crear un laboratorio realista que implemente contramedidas, se ha optado por instaurar un Honeypot en uno de los servidores de la DMZ. Normalmente esta herramienta monitoriza o detecta ciberataques para aprender de ellos y evitar su impacto futuro. De esta forma, los Honeypot suelen ser los primeros en detectar intentos de ataque —también se consideran parte de los sistemas de detección de intrusiones o IDS por sus siglas en inglés—, sin exponer información u otros sistemas críticos —aunque suelen imitarlos en la medida de lo posible sin desvelar detalles cruciales—. [[13](https://www.incibe.es/empresas/blog/honeypot-una-trampa-para-los-ciberdelincuentes)]

Para poder engañar al ciberdelincuente, un Honeypot crea servicios falsos proclives a ser atacados (servidor web, base de datos) y registra la manera usada por el atacante para realizar acciones maliciosas. Esto permite al equipo de ciberseguridad comprender técnicas y patrones, así como crear contramedidas efectivas —además de evitar que el ataque sea recibido directamente por el sistema protegido en caso de que los ciberdelincuentes caigan en la trampa que supone un Honeypot—. [[13](https://www.incibe.es/empresas/blog/honeypot-una-trampa-para-los-ciberdelincuentes)]

Existen varios tipos de Honeypots en función del nivel de interacción que ofrecen al atacante, de forma, que cuanto mayor es este nivel de interacción, más realista resulta, pudiendo engañar en mayor medida a los ciberdelincuentes: [[14](https://pmc.ncbi.nlm.nih.gov/articles/PMC8036602/?sec1-sensors-21-02433)]
- **Nivel bajo:** no dispone de servicios reales, sino que simula algunos básicos, ofreciendo una rápida y sencilla instalación y configuración. Sin embargo, es un sistema limitado en cuanto a la obtención de datos relevantes, ya que solo registran cuestiones sencillas como la fecha y hora del ataque, IPs involucradas y puertos.
- **Nivel medio:** emulan servicios con un mayor nivel de detalle, llegando incluso a ser capaces de responder a los atacantes. Este tipo de dispositivos pueden ser utilizados para capturar malware y/o simular vulnerabilidades conocidas, pero están sometidos a un mayor riesgo al dejar que los atacantes puedan hacer mayores interacciones, de forma que una mala configuración puede comprometer al sistema real. En cambio, suele ser una opción con un buen balance entre riesgo y detalle de la información que recaban.
- **Nivel alto:** se basa en el uso de sistemas reales (máquinas vulnerables completas normalmente ubicadas dentro de la red interna de la organización) que imitan entornos de producción reales. Es la opción que más información puede recabar, permitiendo una gran flexibilidad de acciones realizables por los atacantes, sin embargo, esta ventaja suele estar atada a un alto riesgo (se está creando una máquina vulnerable dentro de la red interna).

Para este laboratorio se escoge un Honeypot de **nivel medio**, ya que no requiere tantos recursos como el nivel alto y ofrece credibilidad suficiente para entender como funcionan estos sistemas.

#### Cowrie
Para implementar en el laboratorio un Honeypot se ha optado por usar la herramineta conocida como Cowrie, la cual ofrece un servicio falso tanto de SSH como de Telnet, principalmente diseñado para el registro de ataques de fuerza bruta. Cuenta con dos opciones de funcionamiento según el nivel de interacción deseado: el modo shell que emula un sistema UNIX a través de Python y el modo de alta interacción o modo Proxy, el cual usa servicios reales de SSH y Telnet, pudiendo manejarlos incluso desde servidores emulados con QEMU. [[15](https://docs.cowrie.org/en/latest/README.html#what-is-cowrie)]

En el modo shell, Cowrie puede crear un sistema de ficheros basado en Debian 5.0 con capacidades completas como añadir o borrar ficheros. Además, permite añadir contenido a ficheros para engañar al atacante —por ejemplo, rellenar `/etc/passwd` con contenido verosímil—. También es capaz de almacenar ficheros que un atacante descargue con `wget`, `curl` o protocolos como SFTP o SCP, lo cual facilita el registro de muestras de malware. [[15](https://docs.cowrie.org/en/latest/README.html#what-is-cowrie)]

De esta forma, para el laboratorio resulta ideal el formato de media interacción, ya que no es necesario tener los servicios reales, sino que basta con los servicios emulados que permiten una acción interesante como el manejo de ficheros y usuarios (a través de "/etc/passwd"). Por otro lado, este sistema requiere menos recursos, lo cual es positivo para introducirlo dentro de uno de los servidores en lugar de necistar otras máquinas emuladas con QEMU. 

### VPN 
Otra posible contramedida interesante es la VPN o red privada virtual. Esta tecnología busca la comunicación entre dos dispositivos a través de una red privada creada sobre Internet —permite la comunicación segura mediante una red pública insegura—. Su funcionamiento se basa en ocultar direcciones IP y cifrar datos para que nadie no autorizado pueda leerlos. [[16](https://aws.amazon.com/es/what-is/vpn/)]

Una conexión VPN consta normalmente de dos dispositivos: un cliente VPN (máquina local desde la cual se inicia la comunicación) y un servidor VPN. Tras establecer la conexión, cualquier comunicación del dispositivo local pasará por el servidor mediante un túnel seguro —a partir de ese punto el origen aparente de los datos es el servidor—. Este túnel impide la visión de los datos a terceros, incluso a los proveedores de servicios. Esto es posible gracias a un fuerte cifrado de la comunicación al paso del túnel entre máquina y servidor. [[16](https://aws.amazon.com/es/what-is/vpn/)]

Debido a todas las ventajas expuestas anteriormente se opta por esta tecnología para posibilitar la creacción de una comunicación externa hacia dentro de la red interna de manera segura. Esto simula un comportamiento típico en el cual una empresa puede conceder un acceso remoto a la red corporativa a sus trabajadores.

#### OpenVPN
Una de las herramientas más populares para la creación de un servidor VPN es OpenVPN. Esta tecnología de código abierto permite la creación de un servidor que establece un túnel seguro con los clientes. Además, ofrece el software cliente necesario para que estos puedan establecer la conexión con el servidor VPN. [[17](https://nordvpn.com/es/blog/what-is-openvpn)]

Para establecer estas comunicaciones seguras OpenVPN consta de varios pasos, empezando por el proceso de autenticación en el servidor VPN, seguido de la configuración del túnel; hasta la encapsulación y cifrado de los datos que se desean transmitir y finalizando con la transmisión de dicha información a través del túnel creado: [[17](https://nordvpn.com/es/blog/what-is-openvpn)]
![image](https://github.com/user-attachments/assets/7567b755-2db1-4440-88b0-25526a69420a)

### Simulación Access-Point
Además de crear máquinas y establecer contramedidas, es necesario crear puntos de acceso inalámbricos para los ataques contra redes Wi-Fi que se estudiarán. En un entorno simulado no existen ni interfaces inalámbricas por defecto, ni Docker puede crearlas dentro de sus redes. Por tanto, se aprovechan funcionalidades del kernel de Linux. En concreto se utiliza el módulo de pruebas `mac80211_hwsim`, un simulador por software de radios IEEE 802.11 —interfaces inalámbricas para WiFi—, pensado para pruebas y desarrollo en Linux. Este módulo genera múltiples interfaces Wi-Fi virtuales que emulan tarjetas reales y se comunican entre ellas al compartir canal (comando `modprobe mac80211_hwsim radios=<num-interfaces>`). [[18](https://kernel.org/doc/html/next/networking/mac80211_hwsim/mac80211_hwsim.html)]

Gracias a la simulación de este tipo de interfaces se puede optar por el uso de tecnologías que simulan el comportamiento de las redes inalámbricas, en concreto se usan Hostapd y wpa_supplicant para establecer el punto de acceso y comunicarse a él respectivamente. De esta forma, Hostapd se basa en el uso de una interfaz inalámbrica (real o simulada) para generar un punto de acceso IEEE 802.11 que es capaz de usar IEEE 802.1X/WPA/WPA2/EAP/RADIUS en redes WiFi [[19](https://wireless.docs.kernel.org/en/latest/en/users/documentation/hostapd.html)]. Por otro lado, wpa_supplicant maneja interfaces inalámbricas y los detalles necesarios del protocolo IEEE 802.11 para la conexión con puntos de acceso WiFi. [[20](https://docs.voidlinux.org/config/network/wpa_supplicant.html)]

Por último, se aprecia como uno de los protocolos de autenticación WiFi mencionados entre las capacidades de Hostapd (y como parte de los estudiados) es EAP/RADIUS, de forma que es necesario considerar la opción de lanzar un servidor con esta tecnología de autenticación. Por ello se opta para esta misión por el servicio más extendido para la configuración de servidores RADIUS de autenticación, FreeRADIUS. [[21](https://www.freeradius.org/)]

### Kali Linux
La principal idea de este laboratorio es la puesta en prueba de herramientas para lanzar ataques contra redes inalámbricas, de forma que se opta por usar un dispositivo Kali Linux (una de las máquinas Docker) para la realización de los ataques. Esto se debe a la puesta a punto y las herramientas con las que cuenta Kali para la ejecución de ataques de toda índole, haciendo de esta una opción ideal para aprender y ahorrar costosos pasos de configuración. Kali Linux consta de un sistema de código abierto basado en la distribución Debian, junto a un montón de herramientas y funcionalidades dedicadas a la seguridad y las pruebas de penetración (especialmente interesante para el objetivo de este laboratorio). [[22](https://www.kali.org/)]

Dentro de las herramientas proporcionadas por el entorno de Kali Linux, las más destacadas para este proyecto son aquellas relacionadas con ataques a redes WiFi. En concreto, se destaca el uso del paquete "aircrack-ng", el cual cuenta con un conjunto de herramientas para la captura de tráfico inalámbrico o la ruptura/captura de contraseñas. [[23](https://www.infosecinstitute.com/resources/penetration-testing/kali-linux-top-8-tools-for-wireless-attacks/)]

### ShellShock
Además, de los ataques directamente relacionado con redes inalámbricas, se deben considerar otros ataques que permitan una verdadera explotación de todo lo introducido en el laboratorio. De esta forma surge la idea de integrar algunas máquinas que presentan servicios vulnerables con el objetivo de mostrar los efectos de lo que sucede cuando un atacante consigue un acceso ilegítimo en nuestra red. Es por esto que una de las máquinas vulnerables introducidas será un dispositivo que cuente con una popular vulnerabilidad en sistemas UNIX conocida como ShellShock (CVE-2014-6271) [[24](https://www.incibe.es/en/incibe-cert/early-warning/vulnerabilities/cve-2014-6271))].

La vulnerabilidad ShellShock, también conocida como Bashdoor (y con nombre oficial GNU Bash Remote Code Execution Vulnerability), consistía en un ataque que permitía la ejecución de código remoto en millones de servidores y otros computadores en todo el mundo.  Este error se fundamenta principalmente en el uso de servidores HTTP que se ejecutan en FastCGI o CGI (permite la ejecución de scripts externos), lo cual da la posibilidad de exponer una consola Bash a los usuarios en una cierta URI como "http://miweb.com/cgi-bin/script.sh". Esto hace que el servidor ejecute "script.sh" con algún intérprete como Bash. [25](https://journal.espe.edu.ec/ojs/index.php/geeks/article/view/279)]

Esta exposición se hace realmente peligrosa porque estos servidores suelen pasar una serie de variables de entorno a los scripts que ejecutan. De esta forma, se aprovecha la posibilidad que ofrece Bash para dar valor a una variable de entorno con una función. Es más, Bash permite incluso en versiones vulnerables ejecutar cualquier comando que estuviera después de una función cerrada: [25](https://journal.espe.edu.ec/ojs/index.php/geeks/article/view/279)]
```
GET /cgi-bin/vulnerable HTTP/1.1
User-Agent: () { :; }; /bin/cat /etc/passwd
```
Esto sería un ejemplo de cómo ejecutar un comando (`/bin/cat /etc/passwd`) gracias a alterar la cabecera de una petición HTTP para cambiar el `User-Agent`, lo cual se traduce en la instauración de esta función y lo que le sigue en la variable de entorno `HTTP_USER_AGENT`, que luego será pasada al script ejecutado de tal forma que éste ejecute el comando malicioso.
```
HTTP_USER_AGENT='() { :; }; /bin/cat /etc/passwd'
```

### Metasploitable3
Por otro lado, se ha instaurado una famosa máquina que expone una serie de servicios vulnerables, diseñada así con el objetivo de servir como entrenamiento para los expertos en ciberseguridad ofensiva que desean reforzar sus habilidades, lo cual encaja a la perfección con el objetivo principal de este proyecto. Esta máquina es Metasploitable 3 [[26](https://www.rapid7.com/blog/post/2016/11/15/test-your-might-with-the-shiny-new-metasploitable3/)], una máquina virtual de código abierto que surge del proyecto Metasploitable financiado por Rapid7 [[27](https://www.rapid7.com/products/metasploit/)]. En concreto, la versión Metasploitable 3 parte de una máquina Ubuntu 14.04 (la usada para este laboratorio) o Windows Server 2008, instaurando servicios con vulnerabilidades como SSH o MySQL.

Metasploit no solo es un proyecto que ofrece máquinas vulnerables, sino que también ayuda a explotarlas gracias a una gran base de datos que permite a los usuarios la importación y exportación de exploits. Esto facilita en gran medida poder encontrar el exploit ideal no solo para conseguir acceso en las máquinas Metasploitable, sino que también resulta de utilidad para otros servicios reales [[28](https://riull.ull.es/xmlui/bitstream/handle/915/28744/Pentesting%20en%20entornos%20controlados.pdf)]. Esta funcionalidad dada por Metasploit facilita mucho los primeros pasos de los profesionales que se introducen en el mundo de la ciberseguridad, siendo este el principal motivo de su uso en el entorno diseñado.

## Esquema del laboratorio
Aquí podemos ver la configuración del laboratorio, tanto desde un punto de vista más visual o esquemático:
![Esquema-Redes](https://github.com/user-attachments/assets/194803dd-dcd5-4c80-b6f5-c387f4b2d2bc)

```
# Esquema general del repositorio
📁 dmz
├── 📁 dmz1
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 dmz2
│   ├── Dockerfile
│   ├── start.sh
│   └── ...

📁 external
├── Dockerfile
├── start.sh
└── ...

📁 fw
├── Dockerfile
└── start.sh

📁 internal
├── 📁 int3
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 int4
│   ├── Dockerfile
│   └── start.sh
├── 📁 int12
│   ├── Dockerfile
│   ├── start.sh
│   └── ...
├── 📁 wireless
│   ├── 📁 AP
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 attacker
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 client3
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...
│   ├── 📁 client12
│   │   ├── Dockerfile
│   │   ├── start.sh
│   │   └── ...

📄 docker-compose.yml  
📄 launch.sh  
📄 README.md  
📄 stop.sh
```

A continuación se describen con más detalle los ficheros que construyen el entorno, empezando por algunos detalles del fichero [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/docker-compose.yml) que define las distintas máquinas y redes internas creadas con Docker:
```
# Fichero docker-compose.yml
...
networks:  
  external-network: 
    driver: bridge 
    ipam:
      config:
        - subnet: 10.5.0.0/24 
          gateway: 10.5.0.254 

  DMZ:
    driver: bridge
    ipam:
      config:
        - subnet: 10.5.1.0/24
          gateway: 10.5.1.254

  internal-network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.5.2.0/24
          gateway: 10.5.2.254
```
```
# Ficheros start.sh con conexiones cableadas
...
route add default gw 10.5.0.1
route del default gw 10.5.0.254
...
```
Lo primero que hay que destacar es cómo se crean las distintas subredes usadas para definir el laboratorio, donde se aprecia que se usa la dirección finalizada en `.254` de cada una de ellas a modo de gateway, lo cual difiere de lo mencionado en la introducción, donde se toman las direcciones terminadas en `.1` como tal (las de las interfaces correspondientes de `fw`). Esto se debe a que en otros lugares, como la definición de cada máquina, se usan estas direcciones:
```
# Algunos ejemplos
...
# Firewall device
  fw: 
    image: bin/fw 
    build: ./fw
    container_name: fw
    networks: 
      external-network:
        ipv4_address: 10.5.0.1 
      DMZ:
        ipv4_address: 10.5.1.1
      internal-network:
        ipv4_address: 10.5.2.1
    privileged: true 
    tty: true

# External device
  external:
    image: bin/external
    build: ./external
    container_name: ext1
    networks:
      external-network:
        ipv4_address: 10.5.0.20 
    depends_on:
      - fw
    privileged: true
    tty: true
...
```
`docker-compose` no permite escribir dos veces la misma dirección IP en un fichero [`docker-compose.yml`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/docker-compose.yml), de forma que se toman estas direcciones `.254` para poder definir los gateway, pero se cambia esta configuración dentro de los ficheros `start.sh` donde resulta necesario. Además, se observa en el ejemplo anterior que las máquinas reciben su configuración de red (IP y subred) al definir la propia máquina en este fichero `.yml`.

Por otro lado, se aprecia cómo en todas las máquinas se define la opción `privileged: true`, dando permisos elevados sobre la máquina que hará de host. Estos permisos son necesarios para trabajar con interfaces de red y otros detalles, pero especialmente en las máquinas inalámbricas que no toman ninguna de las redes (`network_mode: "none"`) vistas anteriormente, al ser necesario crear las interfaces inalámbricas desde una máquina con kernel Linux que actúe como anfitriona (la máquina usada para lanzar el laboratorio):
```
# Algunos ejemplos dentro de docker-compose.yml
...
# WLAN devices
  access-point-1:
    image: bin/access-point
    build: ./internal/wireless/AP
    container_name: ap
    networks:
      internal-network:
        ipv4_address: 10.5.2.24
    depends_on:
      - fw
    privileged: true
    tty: true

  client-1:
    image: bin/client
    build: ./internal/wireless/client12
    container_name: client1
    network_mode: "none"
    depends_on:
      - access-point-1
    privileged: true
    tty: true
...
```
Esto se debe a que Docker tiene un límite al usar el kernel Linux anfitrión, de forma que no puede ejecutar comandos como `modprobe mac80211_hwsim` para la creación de interfaces inalámbricas virtuales. Debido a la necesidad de crear estas redes inalámbricas, surge el fichero [`launch.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/launch.sh), el cual se encarga de la creación de dichas interfaces así como de la adjudicación de estas a las máquinas Docker que las usarán:
```
# Porción del fichero launch.sh para lanzar las máquinas Docker y crear las interfaces inalámbricas
...
docker-compose build
docker-compose up -d
sleep 20
# docker-compose ps

# Assign wireless interfaces to containers
# Create virtual wireless interfaces
modprobe mac80211_hwsim radios=5
...
```
Además, no solo hace falta crear dichas interfaces, sino que se usan los namespaces de Linux con objeto de que cada una de las interfaces creadas sea usada por una única máquina dentro de la red inalámbrica:
```
# Porción de código launch.sh donde se manejan los namespaces
...
# Associate each wireless interface to pid container network namespace
ln -s /proc/"$AP_PID"/ns/net /var/run/netns/"$AP_PID"
ln -s /proc/"$CLIENT1_PID"/ns/net /var/run/netns/"$CLIENT1_PID"
ln -s /proc/"$CLIENT2_PID"/ns/net /var/run/netns/"$CLIENT2_PID"
ln -s /proc/"$CLIENT3_PID"/ns/net /var/run/netns/"$CLIENT3_PID"
ln -s /proc/"$ATTACKER_PID"/ns/net /var/run/netns/"$ATTACKER_PID"
iw phy "$WLAN0_PHY" set netns "$AP_PID"
iw phy "$WLAN1_PHY" set netns "$CLIENT1_PID"
iw phy "$WLAN2_PHY" set netns "$CLIENT2_PID"
iw phy "$WLAN3_PHY" set netns "$CLIENT3_PID"
iw phy "$WLAN4_PHY" set netns "$ATTACKER_PID"
...
```
De esta misma forma, se recomienda encarecidamente el uso del fichero [`stop.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/stop.sh), el cual se encarga de destruir la adjudicación de namespaces y las interfaces creadas:
```
#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Exec like root please" >&2
  exit 1
fi

# Clean symlinks in netnamespaces
find -L /var/run/netns -type l -delete

# Destroy wireless interfaces and stop services
modprobe mac80211_hwsim -r
docker-compose down
```
Una vez analizados los ficheros que definen en rasgos más generales el laboratorio, es decir, los ficheros de configuración que levantan las máquinas, es hora de continuar viendo la configuración de cada uno de los dispositivos que componen las distintas redes.


### Red externa
Aquí únicamente se visualiza una máquina Ubuntu que parte de la imagen "httpd" [[29](https://hub.docker.com/_/httpd)] proporcionada directamente por Apache con todo lo necesario para crear fácilmente un servidor Apache HTTP/HTTPS. Además de esto, cuenta con todos los ficheros de configuración ([`index.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/external/index_ext1.html) y [`ssl.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/external/ssl.conf)) para exponer un servicio HTTP y HTTPS que muestra un sencillo login (aunque este no es realmente funcional; solo sirve para mostrar cómo se puede clonar fácilmente). Por otro lado, contiene todo lo necesario (claves y [`client.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/external/client.conf), es decir, el fichero de configuración de OpenVPN para la conexión cliente) para establecer la conexión VPN con el servidor destinado para ello dentro de la red interna, así como un fichero de arranque ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/external/start.sh)) que simplemente ejecuta el servicio SSH en primer plano con objeto de poder conectarnos para realizar pruebas (esto se repetirá en todas las máquinas a excepción de `fw`, añadiendo algún pequeño detalle cuando sea necesario, como la ejecución de los servicios que implementa).
```
📁 external
├── Dockerfile
├── ca.crt
├── client.conf
├── client.crt
├── client.key
├── index_ext1.html
├── ssl.conf
└── start.sh
```


### Red DMZ
Por otro lado, la red DMZ cuenta con dos dispositivos con una configuración similar, pero con pequeñas diferencias en las contramedidas que implementan. Por un lado se encuentra DMZ1, una máquina centrada en ofrecer una protección basada en el honeypot Cowrie. Mientras que la máquina DMZ2 busca ofrecer un nivel más alto de protección en la conexión mediante SSH, añadiendo características de *hardening*.
```
📁 dmz
├── 📁 dmz1
│   ├── Dockerfile
│   ├── index_dmz1.html
│   ├── ssl.conf
│   └── start.sh
└── 📁 dmz2
    ├── 📁 .ssh
    ├── Dockerfile
    ├── banner.sh
    ├── google_authenticator
    ├── index_dmz2.html
    ├── jail.local
    ├── sshd_config
    ├── ssl.conf
    ├── start.sh
    └── syslog.conf

```


#### DMZ1
Nuevamente se ve un `Dockerfile` que parte de la imagen "httpd" de Apache para generar el respectivo servidor HTTP/HTTPS con la ayuda de los ficheros [`ssl.conf`](http://github.com/Carlosdm06/TFG-Pentesting/blob/config/dmz/dmz1/ssl.conf) (conexión HTTPS) e [`index_dmz1.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz1/index_dmz1.html) (página principal). Por otro lado, destaca la configuración de Cowrie, la cual se realiza no mediante el [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz1/start.sh), sino por medio del propio [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz1/Dockerfile):
```
# Porción del Dockerfile que configura el Honeypot
...
# Cowrie config
#RUN adduser --disabled-password --gecos "" cowrie 
RUN adduser --disabled-password cowrie 

USER cowrie
WORKDIR /home/cowrie

RUN git clone https://github.com/cowrie/cowrie.git
WORKDIR /home/cowrie/cowrie

RUN python3 -m venv cowrie-env && \
    /bin/bash -c "source cowrie-env/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

RUN cp /home/cowrie/cowrie/etc/userdb.example /home/cowrie/cowrie/etc/userdb.txt && \
    sed -ri "s/^#?hostname\s+.*/hostname = carlos/" /home/cowrie/cowrie/etc/cowrie.cfg.dist && \
    echo "carlos:x:1234" >> /home/cowrie/cowrie/etc/userdb.txt
...
```
A diferencia del dispositivo anterior, este no solo expone SSH, sino que configura una regla `iptables` con el objetivo de redirigir el tráfico externo que intenta una conexión SSH (el puerto 22 es el puerto por defecto para SSH) hacia el puerto 2222, donde se expone el servidor Cowrie. De esta forma, se tiende una trampa a los usuarios externos mientras se permite un acceso SSH normal a los usuarios legítimos (red interna principalmente).
```
iptables -t nat -A PREROUTING -s 10.5.0.0/24 -p tcp --dport 22 -j DNAT --to-destination :2222
```


#### DMZ2
Esta máquina cuenta con las mismas capacidades para exponer un servicio web HTTP/HTTPS con un pequeño mensaje que permita reconocer su procedencia (“¡Hola! Soy el servidor conocido como DMZ2”) gracias a los ficheros [`ssl.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/ssl.conf) (conexión HTTPS) e [`index_dmz2.html`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/index_dmz2.html) (página principal). En cambio, sustituye el uso de Cowrie como contramedida por la protección de SSH a través de un doble factor de autenticación ([`google_authenticator`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/google_authenticator)) combinado con la capacidad de bloquear el tráfico proveniente de direcciones IP que han realizado demasiados intentos fallidos (2 en este caso). Esto último es posible gracias al servicio *fail2ban* (configurado en [`jail.local`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/jail.local)) que trabaja en combinación con SSH, bloqueando las IP que realizan demasiados intentos mediante reglas `iptables`. 

Además, son necesarios el fichero [`syslog.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/syslog.conf) para indicarle al servicio *syslog* que debe registrar los intentos fallidos de conexión a SSH, así como el fichero [`sshd_config`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/sshd_config) para cambiar la configuración de SSH, permitiendo así la adición de todas estas funcionalidades, además de cambiar el puerto en el que trabaja SSH al 2222 para que los atacantes no puedan reconocerlo directamente (por defecto es el 22). Por otro lado, se establece el directorio [`.ssh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/config/dmz/dmz2/.ssh), el cual almacena las claves necesarias para permitir una autenticación mediante clave pública/privada al servicio SSH. También se ha optado por dar un toque más de detalle al servidor DMZ2 gracias a la personalización del *banner* ([`banner.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/dmz/dmz2/banner.sh)) mostrado al autenticarse en SSH.

### Red interna (cableada)
En esta red se implementan dos máquinas Ubuntu sencillas que actúan como usuarios normales de la red interna con capacidad de acceso a los servidores para su administración, junto a otra máquina de características similares que además ofrecerá un servidor VPN a través de OpenVPN. Además, se instala una máquina con la vulnerabilidad ShellShock, así como un punto de acceso inalámbrico que estará conectado a la red interna de forma cableada para hacer que la red inalámbrica que crea forme parte de la red interna.
```
📁 internal
├── 📁 int12
│   ├── 📁 .ssh
│   ├── Dockerfile
│   └── start.sh
├── 📁 int3
│   ├── Dockerfile
│   ├── ca.crt
│   ├── dh.pem
│   ├── server.conf
│   ├── server.crt
│   ├── server.key
│   └── start.sh
├── 📁 int4
│   ├── Dockerfile
│   └── start.sh
└── 📁 wireless
```


#### int12
Las máquinas int1 e int2 son dos máquinas idénticas que implementan una sencilla máquina Ubuntu 24.04 a la que únicamente se le añade un servicio SSH para mantenerlas activas y permitir la conexión por motivos de administración y pruebas del laboratorio. Esto se ve reflejado entre el fichero [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int12/Dockerfile) y el script de arranque [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int12/start.sh). Además, contienen un directorio [`.ssh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int12/.ssh) que permite la autenticación vía clave pública/privada en el servicio SSH del servidor DMZ2 (contraseña para usar la clave privada = "1234"). Finalmente, se puede apreciar en el fichero de arranque una entrada añadida a la tabla de enrutamiento:
```
# Porción de start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24
...
```


Esta entrada se usa para que la red interna sea capaz de ubicar la subred inalámbrica dentro de esta red (a través del punto de acceso) y pueda comunicarse con ella fácilmente, siendo esto un comportamiento que se repite en el resto de máquinas cableadas de la red interna (excepto en el punto de acceso, que ya está directamente conectado a esta subred).

#### int3
Contiene las mismas características que las dos máquinas anteriores a excepción de las claves SSH para la conexión con DMZ2 (aunque puede conectarse igualmente con usuario y clave). De esta forma, el fichero [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int3/Dockerfile) tiene una configuración muy similar, añadiendo la copia dentro de la imagen que se creará, de los ficheros relacionados con claves del servicio OpenVPN que expone en el puerto 1194, así como el fichero de configuración [`server.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int3/server.conf) para este mismo servicio, donde se definen las características del servidor VPN. Además, en [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int3/start.sh) se aprecia, a mayores que en las máquinas int1 e int2, una serie de reglas `iptables` que permiten la conexión VPN:
```
# Porción de start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24

# Allow and config VPN
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
...
```

Más concretamente, se permite el tráfico que atraviesa esta máquina (desactivado por defecto) para que pueda ser redirigido a la red interna, donde la subred `10.8.0.0/24` representa una red creada por el servidor VPN para enmascarar las IP de origen reales de los clientes que se conectan (especificado en [`server.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int3/server.conf)). De esta forma, el tráfico proveniente de esa subred es redirigido a través de la máquina int3 hacia la red interna (sale por la interfaz `eth0` de int3), siendo enmascarado con la IP de origen de esta máquina.

#### int4
Esta máquina representa un dispositivo vulnerable que parte de la imagen "vulnerables/cve-2014-6271" [[30](https://hub.docker.com/r/vulnerables/cve-2014-6271)], como se ve en su fichero [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int4/Dockerfile). De esta forma, se crea una máquina que realmente es Ubuntu, pero simula una vulnerabilidad típica de Windows, lo cual nos permite añadir el servicio SSH típico de todas las máquinas del laboratorio, junto a la modificación de la tabla de enrutamiento para permitir el acceso a la subred inalámbrica ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/int4/start.sh)):
```
# Porción de start.sh
...
# Allow connections with WLAN
ip route add 10.5.2.128/26 via 10.5.2.24
...
```


### Red interna (inalámbrica)
Además de las máquinas cableadas, en la red interna se crea una subred `10.5.2.128/26` de máquinas inalámbricas, donde el punto de acceso con IP `10.5.2.129` es quien administra esta comunicación y permite la conexión a través de la red interna con el resto de máquinas (tiene las mismas restricciones que las máquinas cableadas, ya que la comunicación pasará por `fw` una vez atraviese el punto de acceso). Igualmente que en la parte cableada, se repite una estructura con dos máquinas Ubuntu 24.04 sencillas acompañadas de una máquina vulnerable, añadiendo como extra una máquina atacante basada en Kali Linux, con la idea de ser la máquina principalmente usada en la ejecución de los distintos ataques que se estudiarán.
```
📁 wireless
├── 📁 AP
│   ├── Dockerfile
│   ├── clients.conf
│   ├── dhcp.conf
│   ├── eap
│   ├── hostapd-config.conf
│   ├── hostapd.conf
│   ├── start.sh
│   └── users
├── 📁 attacker
│   ├── Dockerfile
│   ├── clients.conf
│   ├── dhcp.conf
│   ├── eap
│   ├── freeradius-server-3.2.7.tar.gz
│   ├── hostapd-config.conf
│   ├── hostapd.conf
│   ├── radius.conf
│   ├── start.sh
│   ├── ssh_passwords.txt
│   ├── ssh_usernames.txt
│   ├── users
│   ├── wpa_supplicant-config.conf
│   └── wpa_supplicant.conf
├── 📁 client12
│   ├── Dockerfile
│   ├── start.sh
│   ├── wpa_supplicant-config.conf
│   ├── wpa_supplicant_wlan1.conf
│   └── wpa_supplicant_wlan2.conf
└── 📁 client3
    ├── Dockerfile
    ├── start.sh
    ├── wpa_supplicant-config.conf
    └── wpa_supplicant.conf
```

Aquí se presentan una serie de ficheros comunes entre las distintas máquinas, empezando por los ficheros [`wpa_supplicant.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client3/wpa_supplicant.conf), [`wpa_supplicant_wlan1.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client12/wpa_supplicant_wlan1.conf) y [`wpa_supplicant_wlan2.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client12/wpa_supplicant_wlan2.conf), los cuales son muy similares independientemente de la máquina en la que se encuentren, permitiendo establecer la conexión Wi-Fi con el punto de acceso a los distintos clientes (también se incluye en el atacante para facilitar la conexión una vez se obtiene la clave). Estos ficheros pueden sufrir cambios en función de la rama en la que estén, variando según los protocolos de seguridad simulados en cada una de estas, ya que especifican las credenciales de autenticación en el punto de acceso. 

Otro archivo similar en todos los clientes es [`wpa_supplicant-config.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client3/wpa_supplicant.conf), el cual configura el servicio *wpa_supplicant* para permitir todo tipo de configuraciones, incluyendo WEP, gracias a la descarga y compilación de esta herramienta que se aprecia en cualquiera de sus [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client12/Dockerfile). Además, estas máquinas contienen un fichero de arranque [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client3/start.sh) donde se ejecutan los servicios necesarios para conectarse al punto de acceso (excepto en el atacante, el cual tiene las herramientas, pero por definición no debería conocer los detalles de la conexión):
```
# Porción de start.sh
...
wpa_supplicant -i "$IFACE" -c wpa_supplicant.conf -B
sleep 2
dhclient "$IFACE"
...
```
En este fichero también se aprecia cómo los clientes WLAN registran el dominio `carlos.web.com` asociado a la IP `10.5.0.20`, es decir, asocian este dominio al servicio expuesto por la máquina externa (web con proceso de login ficticio). Sin embargo, esto se deja comentado en el fichero destino (`/etc/hosts`), ya que solo será una contramedida que se deja disponible para activar después de ver los efectos adversos de un ataque:
```
echo "10.5.0.20      carlos.web.com" >> /etc/hosts
```

Además, se visualizan dos archivos `.txt`, [`ssh_passwords.txt`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/attacker/ssh_passwords.txt) y [`ssh_usernames.txt`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/attacker/ssh_usernames.txt), los cuales son respectivamente diccionarios de contraseñas y nombres de usuarios que serán usados para realizar ataques de fuerza bruta que prueben todas las combinaciones de estos con objeto de romper las credenciales de un servidor SSH. 

#### AP
Máquina que parte de la imagen `freeradius/freeradius-server:3.2.7` [[31](https://hub.docker.com/layers/freeradius/freeradius-server/3.2.7/images/sha256-42b05de4405b1e745686b9ed0f70307fd43e998b850b3e6bd936733a8c260595)], el cual es un Ubuntu 22.04 preparado para ofrecer un servidor RADIUS de FreeRADIUS. Esto se debe a que se muestra la configuración de la rama [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS), al ser la más completa de todas; sin embargo, en el resto de ramas se parte de una imagen `debian:bookworm-slim`, permitiendo en ambos casos una configuración similar en la cual se instala y compila la herramienta *hostapd*, lo cual se puede apreciar en los respectivos [`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/Dockerfile). Por otro lado, también se aprecia la exposición del servicio SSH para administración típico de todas las máquinas, al cual se le añaden una serie de reglas `iptables` en [`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/start.sh) con el objeto de poder realizar la función de punto de acceso que redirige las comunicaciones que salen de la red inalámbrica hacia la red cableada y viceversa. 
```
# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Drop forwarding traffic by default
iptables -P FORWARD DROP

# Allow forwarding LAN traffic
iptables -A FORWARD -i wlan0 -o wlan0 -s 10.5.2.128/26 -d 10.5.2.128/26 -j ACCEPT

# Allow and masquerade forwarding traffic from wireless to wired interface 
iptables -A FORWARD -s 10.5.2.128/26 -i wlan0 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.5.2.128/26 -i eth0 -o wlan0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.5.2.128/26 -o eth0 -j SNAT --to 10.5.2.24

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

También se aprecia cómo permite la comunicación WLAN entre máquinas inalámbricas y el tráfico interno (*loopback*). Además, se puede ver cómo inicia los servicios relacionados con su función de punto de acceso:
```
# Setup DHCP
touch /var/lib/dhcp/dhcpd.leases
chown root:root /var/lib/dhcp/dhcpd.leases
dhcpd -cf /etc/dhcp/dhcpd.conf wlan0

# Setup hostapd (access point) 
freeradius -i 127.0.0.1 -p 1812 
sleep 2
hostapd /ap/hostapd.conf -B
```

En cuanto a los ficheros de configuración, hay que destacar aquellos comunes a todas las versiones de las ramas, como [`hostapd.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/hostapd.conf) y [`hostapd-config.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/hostapd-config.conf), los cuales resultan similares a sus homónimos de *wpa_supplicant*, siendo la configuración del punto de acceso que creará *hostapd* y la configuración de compilación de esta herramienta para permitir todas las opciones (principalmente porque WEP viene desactivado por defecto), respectivamente. También es común a todas las ramas el fichero [`dhcp.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/dhcp.conf), el cual define el servicio DHCP que proporciona las IP a los clientes que se conectan.

Por otro lado, ficheros como [`clients.conf`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/clients.conf), [`eap`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/eap) y [`users`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/AP/users) son parte de la configuración de WPA/WPA2-Enterprise exclusiva de la rama [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS); estos ficheros conforman la configuración del servicio FreeRADIUS. Definen los usuarios (se usa PEAP), así como la configuración del servidor ofrecido.

#### client12
Nuevamente se presenta una configuración común a dos máquinas sencillas (client1 y client2) que parten de la imagen `debian:bookworm-slim` y que únicamente implementan el servicio SSH para seguir arrancadas una vez se inician con Docker ([`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/internal/wireless/client12/Dockerfile)) y poder conectarnos a ellas para labores administrativas. Introducen únicamente todo aquello relacionado con la conexión a la red Wi-Fi mediante *wpa_supplicant*, lo cual es común al resto de máquinas, como ya se comentó.

#### client3
También se muestra otra máquina sencilla que utiliza la comunicación SSH y todo lo necesario para conectarse al punto de acceso mediante *wpa_supplicant*. En cambio, esta máquina parte de la imagen `kirscht/metasploitable3-ub1404` [[32](https://hub.docker.com/r/kirscht/metasploitable3-ub1404)], que implementa una máquina vulnerable Metasploitable3 [[26](https://www.rapid7.com/blog/post/2016/11/15/test-your-might-with-the-shiny-new-metasploitable3/)] que parte de Ubuntu 14.04 (permite una configuración similar a las máquinas client1 y client2) para crear servicios vulnerables.

#### attacker
La máquina atacante es la más importante de todas, al ser la principalmente manejada a la hora de realizar los distintos ataques estudiados. Parte de una máquina Kali Linux *Rolling* e implementa las herramientas de Kali para realizar pruebas de seguridad de red (`kali-tools-wireless`), así como la configuración común de *wpa_supplicant* para poder establecer comunicación con el punto de acceso en caso de ser necesario (aunque por defecto no se conecta para que los ataques tengan sentido). También cuenta, exclusivamente en esta rama (basada en la rama [`WPA/WPA2-RADIUS`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/WPA/WPA2-RADIUS)), con todo lo necesario para establecer un servidor FreeRADIUS, necesario para conseguir acceso ilegítimo en el punto de acceso que usa esta misma tecnología.

### Máquina `fw` (en todas las redes)
Otra máquina que cobra mucha importancia es la que representa el *firewall*, la cual es el punto intermedio que une todas las redes. Esta máquina tiene una configuración básica de Ubuntu 24.04 donde se expone el mismo servicio SSH que en el resto del laboratorio ([`Dockerfile`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/fw/Dockerfile)). Sin embargo, implementa una serie de reglas `iptables` que hacen posible su misión como cortafuegos ([`start.sh`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/blob/config/fw/start.sh)):
```
# Porción de start.sh relativa a las reglas firewall
...
# Allow forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Change defaults policies to drop input and forward traffic and allow output and loopback traffic
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Allow response traffic at TCP and UDP traffic to fw machine
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT             #icmp packets are considered RELATED traffic to iptables
iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
#iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT                       #Accept ping requests to fw (changed by limit option)

# Allow response traffic at ICMP, TCP and UDP traffic that go through fw machine
iptables -A FORWARD -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT                        #icmp packets are considered RELATED traffic to iptables

# Allow TCP, UDP and ICMP since intranet to extranet
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p tcp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p udp -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.0.0/24 -p icmp -j ACCEPT

# Masquerade Intranet to extranet comunications (using SNAT because IP is always the same)
iptables -t nat -A POSTROUTING -s 10.5.2.0/24 -d 10.5.0.0/24 -j SNAT --to 10.5.0.1

# Allow HTTP request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 80 -j ACCEPT

# Limit icmp request to fw (avoid DOS attacks)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/minute --limit-burst 10 -j ACCEPT

# Allow SHH admin comunications since intranet to dmz servers
# iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.0/24 -p tcp --dport 22 -j ACCEPT        # for more secure divide this rule in two:
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT           # for more restrictive admin conexion
#iptables -A FORWARD -s 10.5.2.20 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT          # Allow all internal network to admin dmz servers
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT

# Allow HTTPS request since intranet and extranet to servers (dmz net)
iptables -A FORWARD -s 10.5.2.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.0/24 -p tcp --dport 443 -j ACCEPT

# Define VPN conection 
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT            #neccesary for vpn admin connection (for more restrictive admin conexion)
#iptables -A FORWARD -s 10.5.2.22 -d 10.5.1.21 -p tcp --dport 2222 -j ACCEPT               
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.2.22 -p udp --dport 1194 -j ACCEPT
iptables -A FORWARD -s 10.5.2.22 -d 10.5.2.0/24 -p udp --sport 1194 -j ACCEPT

# Allow external SSH traffic to dmz1 machine (in this machine this traffic is redirect to cowrie honeypot)
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.1.20 -p tcp --dport 22 -j ACCEPT
...
```

[`Volver a la introducción`](https://github.com/carlosdomim02/Wi-Fi-Hacking-Course/tree/main)
