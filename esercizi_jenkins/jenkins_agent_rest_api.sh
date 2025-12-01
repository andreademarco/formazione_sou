#!/bin/bash

# Lo script automatizza la configurazione e l'avvio di un jenkins agent utilizzando le API REST di jenkins
# Le fasi sono: Autenticazione (Crumb), Generazione Token, Creazione Nodo e Avvio Agente.

JENKINS_URL="http://localhost:8080"
JENKINS_USER="andreademarco"
JENKINS_PASSWORD="Isabeau!1234"
COOKIE_FILE="jenkins_cookies.txt"

########### 1. OTTENIMENTO CRUMB ############
# Il crumb è un token che deve essere incluso nelle richieste (tipo PUT e POST) come meccanismo di protezione
CRUMB_RESPONSE=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    --cookie-jar "$COOKIE_FILE" \
    "$JENKINS_URL/crumbIssuer/api/json")  # Richiesta all'endpoint che fornisce il Crumb
                                          # Inoltre salva il cookie di sessione di jenkins in un file .txt

CRUMB_VALUE=$(echo "$CRUMB_RESPONSE" | jq -r '.crumb') # Estrae il token Crumb dalla risposta JSON
CRUMB_FIELD=$(echo "$CRUMB_RESPONSE" | jq -r '.crumbRequestField') # Estrae il nome dell'header HTTP in cui deve essere inserito il Crumb

if [ -z "$CRUMB_VALUE" ] || [ "$CRUMB_VALUE" == "null" ]; then
    echo "Errore: Impossibile ottenere il crumb"
    exit 1
fi           # Check di controllo 

echo "Crumb ottenuto: $CRUMB_VALUE"



########### 2. GENERAZIONE TOKEN API ##############

TOKEN_NAME="my_rest_api_token"

TOKEN_RESPONSE=$(curl -s -X POST \    # Invia una richiesta POST all'endpoint che genera un nuovo token API.
    -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    --cookie "$COOKIE_FILE" \     # Qui seleziona il cookie salvato nel file .txt prima
    -H "$CRUMB_FIELD: $CRUMB_VALUE" \  # Include anche il crumb, necessario per l'operazione POST
    -d "newTokenName=$TOKEN_NAME" \
    "$JENKINS_URL/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken")

API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.data.tokenValue')  # Estrae il valore del nuovo token API dalla risposta JSON.

if [ -z "$API_TOKEN" ] || [ "$API_TOKEN" == "null" ]; then
    echo "Errore generazione token"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

echo "Token API generato: $API_TOKEN"


########### 3. CREAZIONE AGENT NODE ##############

NODE_NAME="my_agent_name"
NODE_DESCRIPTION="Agent per build veloci"
NUM_EXECUTORS="1"
REMOTE_FS="/home/jenkins/agent"
AGENT_TYPE="hudson.slaves.DumbSlave"
PAYLOAD_FILE="/tmp/jenkins_agent_payload.json"

jq -n \        # Costruisce un file JSON con i dettagli di config dell'agente come JNLPLauncher
  --arg name "$NODE_NAME" \
  --arg desc "$NODE_DESCRIPTION" \
  --arg num "$NUM_EXECUTORS" \
  --arg fs "$REMOTE_FS" \
  '{
    "name": $name,
    "nodeDescription": $desc,
    "numExecutors": ($num | tonumber),
    "remoteFS": $fs,
    "labelString": "",
    "mode": "NORMAL",
    "type": "hudson.slaves.DumbSlave",
    "retentionStrategy": {
      "stapler-class": "hudson.slaves.RetentionStrategy$Always"
    },
    "launcher": {
      "stapler-class": "hudson.slaves.JNLPLauncher"
    },
    "nodeProperties": []
  }' > "$PAYLOAD_FILE"

echo "Inizio la creazione dell'agent '$NODE_NAME'..."

CREATE_URL="$JENKINS_URL/computer/doCreateItem?name=$NODE_NAME&type=$AGENT_TYPE"

# Invia richiesta di crezione agente a jenkins
CREATE_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/jenkins_agent_create.out \
  -u "$JENKINS_USER:$JENKINS_PASSWORD" \
  --cookie "$COOKIE_FILE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "$CRUMB_FIELD: $CRUMB_VALUE" \
  --data-urlencode "json@$PAYLOAD_FILE" \     # Come parametro c'è il contenuto del file json sopra 
  "$CREATE_URL")

HTTP_STATUS="$CREATE_RESPONSE"

# Pulisce il file JSON temporaneo
rm -f "$PAYLOAD_FILE"
# Errori vari
if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" ]]; then
    echo " Agent creato con successo! (HTTP $HTTP_STATUS)"
else
    echo " Errore creazione agent (HTTP $HTTP_STATUS)"
    
    if [ "$HTTP_STATUS" == "400" ]; then
        echo "Contenuto della risposta di errore (Potrebbe indicare che il nome esiste già o un problema di parsing JSON):"
    fi
    cat /tmp/jenkins_agent_create.out
    exit 1
fi




########### 4. RECUPERO SECRET AGENT E DOWNLOAD agent.jar ################
echo "### 4. RECUPERO SECRET AGENT E DOWNLOAD agent.jar ###"



LOCAL_WORK_DIR="/tmp/jenkins_agent_work_$(date +%s)" # Usa una directory unica e scrivibile in /tmp
                                                     # Questa è la directory in cui l'agente Java salverà i suoi file e log.
# Mi assicuro che il path esista
mkdir -p "$LOCAL_WORK_DIR"
if [ $? -ne 0 ]; then
    echo " Errore: Impossibile creare la di87rectory di lavoro locale: $LOCAL_WORK_DIR"
    exit 1
fi
echo "🔹 Directory di lavoro locale creata: $LOCAL_WORK_DIR"



JNLP_URL="$JENKINS_URL/computer/$NODE_NAME/jenkins-agent.jnlp"
# Prende il secret generato da jenkins
AGENT_SECRET=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" --cookie "$COOKIE_FILE" "$JNLP_URL" \
    | grep "<argument>" \
    | sed -n 's:.*<argument>\([a-f0-9]\{40,\}\)</argument>.*:\1:p' \
    | head -1)

if [ -z "$AGENT_SECRET" ]; then
    echo " Errore: impossibile estrarre il secret dall'agent JNLP."
    exit 1
fi

echo " Secret Agent: $AGENT_SECRET"

# Avvia l'agente immediatamente
echo "🔹 Avvio l'agente in background..."

java -jar agent.jar \
     -url "$JENKINS_URL" \
     -name "$NODE_NAME" \
     -secret "$AGENT_SECRET" \
     -workDir "$LOCAL_WORK_DIR" &  

# Salva l'ID del processo java in background (per poterlo uccidere in caso)     
AGENT_PID=$!
echo " Agent '$NODE_NAME' avviato in background (PID: $AGENT_PID). Controlla i log in $LOCAL_WORK_DIR"


