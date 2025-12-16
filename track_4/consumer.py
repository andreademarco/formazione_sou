# consumer.py
import json
import time
from kafka import KafkaConsumer

TOPIC_NAME = "foobar"
GROUP_ID = "gruppo-esercizio" #per monitorare il LAG

def run_consumer():
    print("Avvio Consumer...")
    consumer = KafkaConsumer(
        TOPIC_NAME,
        bootstrap_servers='localhost:9092',
        auto_offset_reset='earliest', 
        enable_auto_commit=True,
        group_id=GROUP_ID,
        value_deserializer=lambda x: json.loads(x.decode('utf-8'))
    )

    try:
        for message in consumer:
            print(f"[CONSUMER] Ricevuto: {message.value} (Offset: {message.offset})")
            
            
            time.sleep(0.1) 
    except KeyboardInterrupt:
        print("Consumer interrotto.")

if __name__ == "__main__":
    run_consumer()