echo "  _____  _____   _    _ "
echo " / ____|/ ____| | |  | |"
echo "| (___  | (___  | |__| |"
echo " \___ \  \___ \ |  __  |"
echo " ____) | ____) || |  | |"
echo "|_____/ |_____/ |_|  |_|"
echo "     Carlos's Server    "

echo ""
echo "Bienvenido, $USER!"

LAST_IP=$(last -i | grep "$USER" | head -n 1 | awk '{print $3}')
echo "Tu última conexión fue desde la IP: $LAST_IP"

CURRENT_IP=$(last -i | grep "$USER" | grep "still logged in" | awk '{print $3}')
echo "Tu dirección IP actual es: $CURRENT_IP"

LAST_LOGIN=$(last | grep "$USER" | head -n 1 | awk '{$1=$2=$3=""; print substr($0,4)}')
echo "Tu última conexión fue el: $LAST_LOGIN"
echo "Hoy es: $(date '+%A, %d %B %Y, %T')"

echo "Número de procesos en ejecución: $(ps -u $USER | wc -l)"
echo ""
echo ""
