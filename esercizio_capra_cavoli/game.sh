#!/bin/bash

# ==============================================================================
#  SIMULAZIONE CAPRA E CAVOLI 
# ==============================================================================
# La sequenza vincente è: capra dx, contadino sx, lupo dx, capra sx, cavolo dx, contadino sx, capra dx


echo "--- Inizializzazione ambiente di gioco ---"

mkdir -p ./wgc_build
cd ./wgc_build

# Header standard
header_script='
check_alive() {
  local name=$1
  if [ -f "/tmp/$name.pid" ]; then
    local pid=$(cat "/tmp/$name.pid")
    if kill -0 "$pid" 2>/dev/null; then return 0; fi
  fi
  return 1
}
'

#vari componenti (con sleep iniziale per evitare si mangino subito)

#i due predatori (capra e lupo) controllano la presenza delle prede tramite PID. 
#se la preda (il cavolo o la capra) è presente senza che ci sia il contadino, inviano il kill -9 

#LUPO
cat << EOF > lupo.sh
#!/bin/bash
$header_script
echo \$\$ > /tmp/lupo.pid
echo "[LUPO] (PID \$\$) Mi sto svegliando..." > /proc/1/fd/1
sleep 3 
echo "[LUPO] Ora ho fame!" > /proc/1/fd/1

while true; do
  if check_alive "capra" && ! check_alive "contadino"; then
       echo "GNAM_CAPRA" > /proc/1/fd/1
       kill -9 \$(cat /tmp/capra.pid)
       rm -f /tmp/capra.pid
  fi
  sleep 1
done
EOF

#CAPRA
cat << EOF > capra.sh
#!/bin/bash
$header_script
echo \$\$ > /tmp/capra.pid
echo "[CAPRA] (PID \$\$) Mi sto svegliando..." > /proc/1/fd/1
sleep 3
echo "[CAPRA] Ora ho fame!" > /proc/1/fd/1

while true; do
  if check_alive "cavolo" && ! check_alive "contadino"; then
       echo "GNAM_CAVOLO" > /proc/1/fd/1
       kill -9 \$(cat /tmp/cavolo.pid)
       rm -f /tmp/cavolo.pid
  fi
  sleep 1
done
EOF

#CAVOLO
cat << EOF > cavolo.sh
#!/bin/bash
echo \$\$ > /tmp/cavolo.pid
echo "[CAVOLO] (PID \$\$) ..." > /proc/1/fd/1
while true; do sleep 5; done
EOF

#CONTADINO
cat << EOF > contadino.sh
#!/bin/bash
echo \$\$ > /tmp/contadino.pid
echo "[CONTADINO] (PID \$\$) ..." > /proc/1/fd/1
while true; do sleep 5; done
EOF

chmod +x *.sh

#Dockerfile
cat << 'EOF' > Dockerfile
FROM alpine:latest
RUN apk add --no-cache bash procps
WORKDIR /app
COPY *.sh /app/
CMD ["tail", "-f", "/dev/null"]
EOF

#Build e Deploy
echo "Building Docker Image..."
docker build -t wgc-game-visual . > /dev/null 2>&1
echo "Resetting Containers..."
docker rm -f riva-sx riva-dx > /dev/null 2>&1
docker run -d --name riva-sx wgc-game-visual > /dev/null
docker run -d --name riva-dx wgc-game-visual > /dev/null

#Motore - barca
spawn() {
    local cont=$1
    local char=$2
    docker exec $cont rm -f /tmp/$char.pid
    docker exec -d $cont /bin/bash /app/$char.sh
}

kill_char() {
    local cont=$1
    local char=$2
    docker exec $cont /bin/bash -c "if [ -f /tmp/$char.pid ]; then kill -9 \$(cat /tmp/$char.pid) 2>/dev/null; rm -f /tmp/$char.pid; fi"
}

is_alive() {
    local cont=$1
    local char=$2
    docker exec $cont /bin/bash -c "if [ -f /tmp/$char.pid ] && kill -0 \$(cat /tmp/$char.pid) 2>/dev/null; then echo yes; fi"
}

print_status() {
    clear
    echo "==================================================="
    echo "            STATO DEL FIUME"
    echo "==================================================="
    for riva in riva-sx riva-dx; do
        echo "[$riva]:"
        local found=0
        if [ "$(is_alive $riva lupo)" == "yes" ];      then echo "  - 🐺 LUPO"; found=1; fi
        if [ "$(is_alive $riva capra)" == "yes" ];     then echo "  - 🐐 CAPRA"; found=1; fi
        if [ "$(is_alive $riva cavolo)" == "yes" ];    then echo "  - 🥬 CAVOLO"; found=1; fi
        if [ "$(is_alive $riva contadino)" == "yes" ]; then echo "  - 👨‍🌾 CONTADINO"; found=1; fi
        if [ $found -eq 0 ]; then echo "  (Vuoto)"; fi
    done
    echo "==================================================="
}

check_game_state() {
    print_status
    
    #Logica di controllo
    local capra_viva=0
    local cavolo_vivo=0
    
    [ "$(is_alive riva-sx capra)" == "yes" ] && capra_viva=1
    [ "$(is_alive riva-dx capra)" == "yes" ] && capra_viva=1
    [ "$(is_alive riva-sx cavolo)" == "yes" ] && cavolo_vivo=1
    [ "$(is_alive riva-dx cavolo)" == "yes" ] && cavolo_vivo=1

    # CHECK SCONFITTA
    if [ $capra_viva -eq 0 ]; then
        echo -e "\n\033[0;31m██████████ GAME OVER ██████████\033[0m"
        echo -e "\033[0;31mIL LUPO HA MANGIATO LA CAPRA!\033[0m"
        return 1
    fi
    if [ $cavolo_vivo -eq 0 ]; then
        echo -e "\n\033[0;31m██████████ GAME OVER ██████████\033[0m"
        echo -e "\033[0;31mLA CAPRA HA MANGIATO IL CAVOLO!\033[0m"
        return 1
    fi

    # CHECK VITTORIA
    if [ "$(is_alive riva-dx lupo)" == "yes" ] && \
       [ "$(is_alive riva-dx capra)" == "yes" ] && \
       [ "$(is_alive riva-dx cavolo)" == "yes" ] && \
       [ "$(is_alive riva-dx contadino)" == "yes" ]; then
        echo -e "\n\033[0;32m██████████ VITTORIA! ██████████\033[0m"
        return 2
    fi
    return 0
}

move_logic() {
    local char=$1
    local dest_name=$2 
    local src_cont=""
    local dst_cont=""
    
    if [ "$dest_name" == "dx" ]; then
        dst_cont="riva-dx"; src_cont="riva-sx"
    elif [ "$dest_name" == "sx" ]; then
        dst_cont="riva-sx"; src_cont="riva-dx"
    else
        echo "Errore: Destinazione non valida. Usa 'dx' o 'sx'."
        sleep 2; return
    fi

    if [ "$(is_alive $src_cont $char)" != "yes" ]; then
        echo "Errore: $char non è qui."
        sleep 2; return
    fi

    if [ "$char" != "contadino" ]; then
        if [ "$(is_alive $src_cont contadino)" != "yes" ]; then
            echo "Errore: Il contadino deve essere qui per guidare!"
            sleep 2; return
        fi
    fi

    echo "🚣 Spostamento in corso..."
    
    #Esecuzione spostamento
    if [ "$char" != "contadino" ]; then
        kill_char $src_cont $char       
        kill_char $src_cont "contadino" 
        spawn $dst_cont "contadino"     
        spawn $dst_cont $char           
    else
        kill_char $src_cont "contadino"
        spawn $dst_cont "contadino"
    fi
}

#Inizio
echo "Popolamento in corso..."
spawn riva-sx contadino
spawn riva-sx cavolo
spawn riva-sx capra
spawn riva-sx lupo
sleep 2

#loop
while true; do
    check_game_state
    if [ $? -ne 0 ]; then break; fi

    echo "Comandi: [personaggio] [direzione] (es. 'capra dx')"
    echo "Scrivi 'exit' per uscire."
    echo -n "> "
    read input_line

    if [ "$input_line" == "exit" ]; then break; fi

    set -- $input_line
    param_char=$1
    param_dir=$2

    if [[ "$param_char" =~ ^(lupo|capra|cavolo|contadino)$ ]]; then
        move_logic $param_char $param_dir
        sleep 2 
    else
        echo "Comando non riconosciuto."
        sleep 1
    fi
done

cd ..
rm -rf wgc_build
docker rm -f riva-sx riva-dx > /dev/null
echo ""
echo "Simulazione terminata."