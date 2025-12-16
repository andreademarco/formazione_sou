# producer.py
import time
import json
from kafka import KafkaProducer, KafkaAdminClient
from kafka.admin import NewTopic

TOPIC_NAME = "foobar"
BOOTSTRAP_SERVERS = 'localhost:9092'

def create_topic_if_not_exists():
    try:
        admin_client = KafkaAdminClient(bootstrap_servers=BOOTSTRAP_SERVERS)
        existing_topics = admin_client.list_topics()
        
        if TOPIC_NAME not in existing_topics:
            print(f"Il topic '{TOPIC_NAME}' non esiste. Creazione in corso...")
            topic_list = [NewTopic(name=TOPIC_NAME, num_partitions=1, replication_factor=1)]
            admin_client.create_topics(new_topics=topic_list, validate_only=False)
            print(f"Topic '{TOPIC_NAME}' creato con successo.")
        else:
            print(f"Il topic '{TOPIC_NAME}' esiste già.")
    except Exception as e:
        print(f"Errore nella gestione del topic: {e}")

def run_producer():
    producer = KafkaProducer(
        bootstrap_servers=BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )

    i = 0
    try:
        while True:
            message = {"id": i, "content": f"Messaggio numero {i}"}
            # Invio asincrono
            producer.send(TOPIC_NAME, value=message)
            print(f"[PRODUCER] Inviato: {message}")
            i += 1
            time.sleep(1) #invia 1 messaggio al secondo 
    except KeyboardInterrupt:
        print("Producer interrotto.")
        producer.close()

if __name__ == "__main__":
    create_topic_if_not_exists()
    time.sleep(2) #attesa tecnica iniziale
    run_producer()