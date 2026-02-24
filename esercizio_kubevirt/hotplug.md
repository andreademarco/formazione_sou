# KubeVirt Hotplug

### Problema: 
eseguire le operazioni di

1. aumento CPU,
2. aumento RAM,
3. aggiunta disco

"a caldo" (senza spegnere la VM).

La logica di KubeVirt è dichiarativa, cioè modificando la specifica della VM (il suo manifest) è KubeVirt che si occupa di riconciliare lo stato della **VirtualMachineIstance** (VMI) in esecuzione.

*Nota*: Una VM su KubeVirt sta a una VMI come un Deployment o uno StatefulSet sta ai pod su k8s: assicura che una specifica VMI sia in esecuzione o spenta in base allo stato desiderato. Una VMI nasce da una VirtualMachine quando la si avvia.

## Prerequisiti

- **QEMU Guest Agent**
- Per i dischi, il controller che fa da intermediario tra i dischi e il guest deve essere di tipo SCSI (`virtio-scsi`). Questo controller non è progettato per essere accoppiato ad un disco (1 controller = 1 disco), bensì ci possono essere multiple unità su un singolo controller.
- **FeatureGates** necessarie (funzionalità specifiche che possono essere abilitate nella Custom Resource KubeVirt) sono `DeclarativeHotplugVolumes` (equivalente obsoleto: `HotplugVolumes`) o `WorkloadUpdateMethods`. Il primo abilita il disk hotplug, il secondo permette al virt-operator di gestire gli aggiornamenti delle VMIs. C'è anche il featuregate `ExpandDisks`.

## Componenti

- **QEMU** (Quick Emulator) - Software che esegue la VM emulando l'hardware: crea la CPU virtuale, la RAM virtuale, i controller dei dischi e le schede di rete. In KubeVirt ogni VM è un processo QEMU che gira all'interno di un container su un nodo k8s.
- **Libvirt** - Demone che gestisce la virtualizzazione. Riceve comandi ad alto livello e li traduce per QEMU.
- **QMP** (QEMU Monitor Protocol) - È un protocollo basato su JSON che permette ad applicazioni esterne (come Libvirt) di comunicare con un'istanza QEMU in esecuzione.
- **ACPI** (Advanced Configuration and Power Interface) - Standard industriale che permette al sistema operativo di comunicare con l'hardware per la gestione dell'energia e la configurazione (1996).

## Procedure

### 1 - Aumento CPU

L'hotplug della CPU consiste nella modifica del manifest della VM aumentando il numero di socket (`spec.domain.cpu.sockets`).
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
spec:
  template:
    spec:
      domain:
        cpu:
          sockets: 2
          cores: 1
          threads: 1
          maxSockets: 4     # prealloca le risorse all'avvio
```

L'API server di KubeVirt nota la differenza del numero di CPU richieste. Il pod di controllo (`virt-controller`) verifica che il numero sia minore di quanto dichiarato quando la VM è stata accesa. Se la richiesta è valida, il controller aggiorna la VMI, che rappresenta la VM in esecuzione.

Il `virt-handler` del nodo specifico su cui sta girando la VM nota che la VMI è stata aggiornata dal controller. A questo punto, il suo compito è applicare questa modifica localmente: chiama l'API di Libvirt utilizzando la funzione `virDomainSetVcpus` nel codice Go.

Libvirt riceve l'ordine e stabilisce una connessione con il processo QEMU di quella specifica VM utilizzando il protocollo QMP. Tramite questa connessione socket, Libvirt invia a QEMU un comando in formato JSON che dice di attivare le CPU aggiuntive.

QEMU riceve il comando QMP e siccome alla creazione erano stati definiti un numero massimo di socket (solo quelli utilizzati erano attivi), quelli inattivi finora vengono resi online.

Siccome l'hardware virtuale è cambiato, QEMU genera un segnale (interrupt ACPI) che notifica il sistema operativo guest. Infine il kernel del guest capisce che c'è una nuova CPU disponibile, la inizializza e la sfrutta.

**Schema:**
```
Modifico il manifest YAML
         │
         ▼
  KubeVirt API Server
  rileva il delta su spec.domain.cpu
         │
         ▼
  virt-controller (pod di controllo)
  valida la richiesta (non supera maxSockets?)
         │
         ▼
  virt-handler (DaemonSet sul nodo fisico)
  agente locale che parla con Libvirt
         │
         ▼
  Libvirt → virDomainSetVcpus()
  invia il comando a QEMU tramite QMP socket
         │
         ▼
  QEMU attiva lo slot CPU pre-allocato
  (transizione offline → online)
         │
         ▼
  Il kernel guest riceve un evento ACPI
  "CPU hotplug notification"
         │
         ▼
  Il kernel guest porta online la vCPU
  (visibile in /sys/devices/system/cpu/)
```

### 2 - Aumento RAM

Il processo è simile:

Modifico il manifest (`spec.domain.memory.guest`) → il KubeVirt API rileva la modifica → il `virt-controller` valida la richiesta → `virt-handler` → Libvirt invia all'emulatore QEMU un comando tipo `device_add dimm, size=2G, slot=1` che aggiunge un nuovo banco di memoria virtuale (Dual In-line Memory Module) nello slot numero 1 della scheda madre → QEMU mappa il nuovo DIMM nello spazio fisico guest, poi genera un evento ACPI "Memory Hotplug" → il kernel guest riceve l'interrupt e agisce di conseguenza.

### 3 - Aggiunta Disco

Questo è il caso più semplice (non bisogna scegliere un tetto massimo alla creazione della VM): il disco della VM è un PVC di k8s, quindi si possono aggiungere volumi finché ci sono PVC disponibili.

**Processo:**

Creo un PVC tramite manifest → Uso il comando `virtctl addvolume` (o modifico il manifest) → l'API di KubeVirt riceve la richiesta, il kubelet monta la PVC nel filesystem del pod `virt-launcher` → `virt-handler` contatta QEMU → come sopra, evento hardware.

## Confronto con la Virtualizzazione Classica

In VMware, ad esempio, la gestione è **imperativa** (tramite vCenter, script o comandi diretti), mentre KubeVirt è **dichiarativo**.

Per VMware, l'hypervisor ESXi **è** il sistema operativo della macchina. Non c'è nulla sotto tranne l'hardware:
```
┌─────────────────────────────────┐
│   VM 1   │   VM 2   │   VM 3   │
├─────────────────────────────────┤
│         HYPERVISOR (ESXi)       │  ← gira direttamente sull'hardware
├─────────────────────────────────┤
│         HARDWARE FISICO         │
└─────────────────────────────────┘
```

Su KubeVirt c'è invece un approccio hosted:
```
┌─────────────────────────────────┐
│  Pod (virt-launcher + QEMU)     │  ← la VM è un processo
├─────────────────────────────────┤
│         KUBERNETES              │
├─────────────────────────────────┤
│    LINUX + KVM (kernel module)  │  ← KVM è il ponte verso l'hardware
├─────────────────────────────────┤
│         HARDWARE FISICO         │
└─────────────────────────────────┘
```

Per assegnare le risorse in VMware, vCenter dice a ESXi di dare più memoria fisica alla VM e il gioco è fatto. Su KubeVirt l'allocazione avviene invece su due livelli:

1. Kubernetes deve dare risorse al Pod.
2. QEMU nel pod dà quelle risorse alla VM guest.

In VMware il CPU/RAM hot add va abilitato prima dell'avvio della VM, esattamente come il `maxSockets` di KubeVirt. L'aggiunta di un disco a caldo avviene collegando un VMDK tramite vCenter, che è l'analogo del PVC in KubeVirt.