#!/usr/bin/env bash
# Uso: ./check_locked.sh 

LOCKED_COUNT=0                                   # Conteo de bloqueos
UNLOCKED_COUNT=0                                 # Conteo de desbloqueos
LOCKED_COUNT_FILE="/tmp/locked-count"            # Conteo de bloqueos (fichero de recuento compartido entre procesos)
UNLOCKED_COUNT_FILE="/tmp/unlocked-count"        # Conteo de desbloqueos (fichero de recuento compartido entre procesos)
LOCKED_TIMESTAMP_FILE="/tmp/locked-timestamp"    # Instante donde se bloquea
TIMEOUT=360                                      # Tiempo limite para desbloquear (6 min)
WAIT_BTW_CHECKS=60                               # Tiempo de espera entre comprobaciones
IFACE="wlan0"                                    # Interfaz de WPS para los reinicios
PIN=94229882                                     # PIN de WPS para los reinicios

LOG_FILE="/var/log/hostapd-wps.log" 
echo "0" > "$LOCKED_COUNT_FILE"
echo "0" > "$UNLOCKED_COUNT_FILE"
echo "0" > "$LOCKED_TIMESTAMP_FILE"

# Imprime un mensaje en el log propio de este script
log_event() {
    local MESSAGE="$1"
    local LOG_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Proteccion de escritura simultanea
    (
        flock -x 200
        echo "[$LOG_TIMESTAMP] $MESSAGE" >> "$LOG_FILE"
    ) 200>"$LOG_FILE.lock"
}

# Monitoreo del estado de WPS
monitor_timeout() {
    while true; do
        sleep "$WAIT_BTW_CHECKS"
        local LOCKED_COUNT
        local UNLOCKED_COUNT

        # Lectura segura de los contadores
        exec 200<"$LOCKED_COUNT_FILE.lock"
        flock -s 200
        LOCKED_COUNT=$(cat "$LOCKED_COUNT_FILE")
        UNLOCKED_COUNT=$(cat "$UNLOCKED_COUNT_FILE")
        exec 200>&-

        if (( LOCKED_COUNT > UNLOCKED_COUNT )); then
            # Si hay más bloqueos que desbloqueos (actualmente WPS bloqueado)
            # se analiza el tiempo que lleva bloqueado, de forma que al superar el limite 
            local LOCKED_TIMESTAMP=$(cat "$LOCKED_TIMESTAMP_FILE")
            local NOW=$(date +%s)
            local ELAPSED_TIME=$((NOW - LOCKED_TIMESTAMP))

            if (( ELAPSED_TIME > TIMEOUT )); then
                # Llegar aquí supone un bloqueo permanente de WPS o un fallo en hostapd_cli
                # Matar proceso anterior y volver a ejecutarlo 
                # (los clientes antiguos ahora se conectan con WPA/WPA2)
                log_event "[!] Tiempo de bloqueo WPS excedido, reiniciando hostapd..."
                pkill hostapd 

                # Reiniciar valor de UNLOCKED con el valor de LOCKED, ya que se igualan 
                # los desbloqueos a los bloqueos al reiniciar hostapd
                # No seria necesaria la proteccion al no tener proceso hostapd_cli activo,
                # pero se usa igualmente para evitar posibles errores)
                exec 200>"$LOCKED_COUNT_FILE.lock"
                flock -x 200
                echo "$LOCKED_COUNT" > "$LOCKED_COUNT_FILE"
                echo "$LOCKED_COUNT" > "$UNLOCKED_COUNT_FILE"
                exec 200>&-

                
                sleep 2
                hostapd /ap/hostapd.conf -B
                hostapd_cli -i "$IFACE" wps_ap_pin set "$PIN" any         
                log_event "[!] Reinicio de WPS completado tras superar $TIMEOUT s bloqueado." 
            fi
        fi
    done
}

# En segundo plano se monitorea el tiempo que lleva bloqueado WPS
monitor_timeout &

# Monitoreo de eventos hostapd en tiempo real 
while true; do
    # Lee linea a linea para buscar bloqueos y desbloqueos
    # Ademas guarda el log en el fichero LOG_FILE 
    stdbuf -oL hostapd_cli -p "/var/run/hostapd" -i "$IFACE" | while read LINE; do
        log_event "$LINE"

        if echo "$LINE" | grep -q "WPS-AP-SETUP-LOCKED"; then
            # Lectura segura de bloqueos
            exec 200<"$LOCKED_COUNT_FILE.lock"
            flock -s 200
            LOCKED_COUNT=$(cat "$LOCKED_COUNT_FILE")
            exec 200>&-

            # Por cada bloqueo se anota cuantos van y cuando se bloqueo
            LOCKED_COUNT=$((LOCKED_COUNT + 1))

            # Escritura segura de bloqueos
            exec 200>"$LOCKED_COUNT_FILE.lock"
            flock -x 200
            echo "$LOCKED_COUNT" > "$LOCKED_COUNT_FILE"
            exec 200>&-
            
            # Anotar tiempo de bloqueo (aqui no es necesario proteger, el monitor solo lee)
            date +%s > "$LOCKED_TIMESTAMP_FILE"
            log_event "[!] Bloqueo de WPS numero $LOCKED_COUNT."

        elif echo "$LINE" | grep -q "WPS-AP-SETUP-UNLOCKED"; then
            # Lectura segura de desbloqueos
            exec 200<"$LOCKED_COUNT_FILE.lock"
            flock -s 200
            UNLOCKED_COUNT=$(cat "$UNLOCKED_COUNT_FILE")
            exec 200>&-

            # Por cada desbloqueo se actualiza la cuenta de desbloqueos
            UNLOCKED_COUNT=$((UNLOCKED_COUNT + 1))

            # Escritura segura de desbloqueos
            exec 200>"$LOCKED_COUNT_FILE.lock"
            flock -x 200
            echo "$UNLOCKED_COUNT" > "$UNLOCKED_COUNT_FILE"
            exec 200>&-

            log_event "[!] Desbloqueo de WPS numero $UNLOCKED_COUNT."
        fi
    done

    # Llegar aquí se debe a que se ha forzado el cese de hostapd (pkill hostapd)
    # o bien que ha ocurrido algún tipo de fallo que ha cerrado hostapd
    # De esta forma el "while true" se asegura el continuo monitoreo de WPS
    log_event "[!] Proceso hostapd_cli terminado." 
done

