CONTAINER_NAME="echo-server"

#Alias dei nodi (definiti in ~/.ssh/config)
NODE1="m1"
NODE2="m2"
################################################################################################
#Definizione funzione container_running che controlla se il container è in esecuzione su un nodo

container_running() {
    local NODE="$1"                                 #va chiamata con "container_running m1" tipo
    ssh $NODE "docker ps -q -f name=$CONTAINER_NAME" #entra in remoto nel nodo input ed elenca i container sul nodo filtrandoli per nome
}
################################################################################################
#Determina il nodo corrente e il nodo target
if container_running $NODE1 | grep -q .; then     #se output positivo (0) di container_running m1, definiamo m2 come target
    CURRENT_NODE="$NODE1"
    TARGET_NODE="$NODE2"
elif container_running $NODE2 | grep -q .; then
    CURRENT_NODE="$NODE2"
    TARGET_NODE="$NODE1"
else
    CURRENT_NODE=""
    TARGET_NODE="$NODE1"                             #parte dal nodo1 se il container non esiste
fi
################################################################################################
# Ferma e rimuove il container sul nodo corrente
# Ferma e rimuove il container sul nodo corrente
if [ -n "$CURRENT_NODE" ]; then                                           #se c'è un container in esecuzione (se la stringa non è vuota)
    echo "Fermando container su $CURRENT_NODE..."
    ssh $CURRENT_NODE "docker rm -f $CONTAINER_NAME 2>/dev/null || true"  #entra in remoto nel nodo corrente e forza la rimozione del container, 
                                          #con ||true si evita che lo script si interrompa in caso di errore, come ad esempio se il container non esiste
fi
###############################################################################################
# Rimuove eventuale container residuo sul nodo target
ssh $TARGET_NODE "docker rm -f $CONTAINER_NAME 2>/dev/null || true"     #stessa cosa di prima ma sul nodo target (evita che ci siano zombi)

##############################################################################################
# Avvia il container sul nodo target
echo "Avviando container su $TARGET_NODE..."
ssh $TARGET_NODE "docker run -d --name $CONTAINER_NAME -p 0.0.0.0:8080:8080 ealen/echo-server"

echo "Container ora in esecuzione su $TARGET_NODE"


