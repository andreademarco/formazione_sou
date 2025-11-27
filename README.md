# ![Rosso](https://placehold.co/15x15/f03c15/f03c15.png) formazione_sou
### ![Viola](https://placehold.co/15x15/800080/800080.png) Andrea De Marco - Academy #5 DevOps

--- 

### Struttura della repo:
```text
├── esercizi_ansible/
│   ├── deploy.yml
│   ├── esercizio_ansible1.yml
│   ├── limits.conf.j2
│   ├── esercizio_ansible2.yml
│   └── access_whitelist.j2
│
├── esercizi_docker/
│   ├── Dockerfile
│
├── esercizi_git/
│   ├── file_conflittuale
│
├── scripts/
│   ├── find_cron.sh
│   ├── migrate_container.sh
│   └── port_scan.sh
│
└── README.md
```
--- 
### Contenuti
[**Scripts**]:
- lo script _find_cron.sh_ che trova e cancella i file più vecchi di 30g impostando un crontab periodico;
- lo script _migrate_container.sh_ che sposta, disattiva e attiva il container ealen/echo-server su due nodi.
  (Per l'esercizio ping_pong lo script era eseguito in loop tramite comando "while true; do ./migrate_container.sh; sleep 60; done &
") 
- lo script _port_scan.sh_ che prende in input un indirizzo ipv4, una porta di partenza e una porta di fine; controlla che tutti e tre i dati siano corretti e coerenti; infine verifica quali porte sono in ascolto. 

[**Esercizi Ansible**]:
- il playbook _deploy.yml_ che utilizza le REST API di Jenkins per automatizzare e creare un agent node;
- il playbook _esercizio_ansible1.yml_ che attinge al template _limits.conf.j2_ per configurare il numero massimo di file nei vari ambienti;
- il playbook _esercizio_ansible1.2.yml_ che attinge al template _access_whitelist.j2_ per gestire gli utenti autorizzati ad accedere al sitema tramite PAM 
- il playbook _esercizio_ansible2.yml_ che installa una lista di pacchetti in base a quanto definito in un dizionario;
- il playbook _esercizio_ansible2.2.yml_ che crea una lista di utenti usando le informazioni contenute in una lista di dizionari;
- il playbook _esercizio_ansible3.yml_ che legge e stampa da un vault delle variabili; 

[**Esercizi Jenkins**]:
- lo script _jenkins_agent_rest_api.sh_ che utilizza le REST API di Jenkins per automatizzare e creare un agent node;
- la pipeline _Jenkinsfile_ che automatizza il deployment di un'applicazione Flask su Minikube usando Helm Chart;
- la pipeline _Jenkinsfile-date_build_ che esegue il build solo dal lunedi al venerdì e scrive un messaggio di warning il sabato e la domenica;
- la pipeline _Jenkinsile-param_ che esegue uno stage a seconda del parametro in input;

[**Esercizi Git**]:
- un file di testo che generava un conflitto intenzionale su git;

[**Esercizi Docker**]:
- un _Dockerfile_ usato insieme alla pipeline _Jenkinsfile-date_build_ per definire l'immagine da buildare.

[**Esercizi Container**]:
- un _Vagrantfile_ utilizzato per configurare le due VM (docker host e nfs-server) usate per i tre esercizi.



