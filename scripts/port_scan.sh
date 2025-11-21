#!/bin/bash

# Il codice prende in input un indirizzo, una porta di inizio, una di fine e controlla gli indirizzi in ascolto nel range inizio-fine. 
############ # Input 
ip="$1"
start="$2"
end="$3"
timeout=1   # Serve un piccolo delay nello scan

###################################################################   # Set numero di argomenti a 3
if [ $# -ne 3 ]
  then
    echo "Lo script ha bisogno di 3 argomenti per funzionare!"
    exit 1
fi

##################################################################   # Check range con senso
if (( start > end ))
 then
  echo "La porta di inizio è più grande, invertile."
  exit 1
fi

#################################################################   # Check indirizzo IP 

   #rx='([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'    # All'inizio ho scritto così sbagliando:
                                                   # gli zeri davanti sarebbero inclusi 
   #if [[ $ip =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
   
oct="(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])" 
if [[ $ip =~ ^$oct\.$oct\.$oct\.$oct$ ]]; then
     echo "Indirizzo ipv4 valido:     "$ip
  
else
      echo "Indirizzo ipv4 non valido! "$ip
      exit 1
fi

#################################################################   # Check porte numeriche
re='^[0-9]+$'
if ! [[ "$start" =~ $re ]]; then
  echo "La START_PORT non è un numero valido: '$start'"
  exit 1
fi
if ! [[ "$end" =~ $re ]]; then
  echo "La END_PORT non è un numero valido: '$end'"
  exit 1
fi

#################################################################  # Esegue lo scan all'indirizzo stabilito
for ((port=start; port<=end; port++)); do
        if nc -w "$timeout" "$ip" "$port" < /dev/null; then     # chiude stdin 
         echo "OPEN"
        else
         echo "CLOSED/FILTERED"
        fi
done
#####################################################################################################################
