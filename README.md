# formazione_sou
Formazione De Marco Academy #5
Contenuti della repo:
- lo script find_cron.sh che trova e cancella i file più vecchi di 30g impostando un crontab periodico;
- lo script migrate_container.sh che sposta, disattiva e attiva il container ealen/echo-server su due nodi.
  (Per l'esercizio ping_pong lo script era eseguito in loop tramite comando "while true; do ./migrate_container.sh; sleep 60; done &
") 
- lo script port_scan.sh che prende in input un indirizzo ipv4, una porta di partenza e una porta di fine; controlla che tutti e tre i dati siano corretti e coerenti; infine verifica quali porte sono in ascolto. 
