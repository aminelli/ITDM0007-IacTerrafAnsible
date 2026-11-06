# Prompt: progetto Terraform per una VM Azure con Tomcat

Agisci come un Senior Cloud DevOps Engineer con esperienza in Infrastructure as Code, Terraform e Microsoft Azure. Progetta un progetto Terraform completo, sicuro, verificabile e pronto per essere esaminato e distribuito.

## Obiettivo

Effettua il provisioning su Azure di una macchina virtuale Linux Ubuntu LTS e installa Tomcat 10 e Java 21. Fornisci il codice HCL completo e una documentazione operativa dettagliata in italiano.

## Requisiti infrastrutturali

- Crea un Resource Group, una Virtual Network, una subnet, una Network Interface, un Network Security Group e una macchina virtuale Linux.
- La VM deve avere esattamente 2 vCPU e 4 GB di RAM. Scegli una SKU Azure che soddisfi entrambi i requisiti e verifica che sia disponibile nella regione configurabile. Non sostituirla con una SKU non equivalente senza dichiararlo.
- Usa un'immagine Ubuntu LTS di Canonical. Non inventare nomi di publisher, offer, SKU o versioni e non affermare che l'immagine corrisponde alla LTS più recente senza averlo verificato. Spiega in modo preciso come viene scelta la versione:
  - se il provider consente di selezionare dinamicamente l'ultima release LTS, usa il meccanismo documentato e funzionante;
  - se è possibile selezionare dinamicamente solo l'ultima versione di una specifica release LTS, distingui chiaramente questo comportamento dall'aggiornamento alla nuova release LTS;
  - se la selezione automatica dell'ultima release LTS non è supportata in modo affidabile, chiedi conferma prima di procedere, proponendo una versione configurabile e documentata.
- Configura l'accesso amministrativo SSH con un nome utente parametrizzato.
- Per l'apertura della porta 22 dusa come CIDR `0.0.0.0/0` come valore predefinito.
- Crea una regola NSG in ingresso per la porta 8080, necessaria per raggiungere Tomcat. Rendi configurabile il CIDR sorgente e dichiara chiaramente se l'applicazione sarà accessibile pubblicamente o solo da reti autorizzate. Non aggiungere porte non richieste.
- La porta 8080 deve essere configurata sia nel servizio Tomcat sia nelle regole di rete Azure. Se proponi anche un firewall del sistema operativo, descrivi e configura separatamente tale livello: una regola NSG non equivale a una regola firewall Linux.
- Usa un disco OS gestito e rendine configurabile la classe di prestazioni, scegliendo un valore compatibile con la SKU e con i requisiti.
- Applica tag comuni a tutte le risorse che li supportano.

## Autenticazione SSH: chiarimento obbligatorio

La richiesta iniziale menziona username e password, ma l'accesso SSH con chiave pubblica è generalmente più sicuro. Prima di generare il codice, chiedi quale modalità desidero:

1. Chiave pubblica SSH, consigliata; oppure
2. Username e password, solo se confermato esplicitamente, con gestione del segreto senza valori in chiaro nel codice, nei file `.tfvars` versionati, nei log o negli output.

Non cambiare tacitamente il requisito e non inserire credenziali reali o segnaposto che sembrino credenziali utilizzabili.

## Installazione e configurazione del software

- Installa Java 21 e Apache Tomcat 10 durante il provisioning, usando un meccanismo ripetibile e adatto a Terraform (ad esempio cloud-init tramite `custom_data`, se appropriato).
- Verifica la disponibilità e i nomi effettivi dei pacchetti per la release Ubuntu scelta; se non sono disponibili dai repository predefiniti, documenta una fonte supportata e le verifiche di integrità necessarie.
- Configura Tomcat come servizio `systemd`, avviato automaticamente dopo il riavvio, in ascolto sulla porta 8080.
- Usa nomi di file, variabili, risorse e script in inglese. Aggiungi commenti solo per chiarire scelte non ovvie.
- Non inserire password, chiavi private o altri segreti nello script di bootstrap o nei file versionati.

## Qualità del progetto Terraform

Organizza il progetto almeno nei seguenti file:

- `versions.tf`: vincoli compatibili e documentati per Terraform e per il provider `azurerm`; evita vincoli vaghi o non verificati.
- `providers.tf` (se utile): configurazione del provider senza credenziali codificate.
- `variables.tf`: variabili con tipo, descrizione, validazioni e default solo quando sensati.
- `main.tf`: risorse e data source.
- `outputs.tf`: output utili, ad esempio nome e IP pubblico della VM, senza esporre segreti.
- `terraform.tfvars.example`: valori di esempio non sensibili e istruzioni sui valori da sostituire.
- `README.md`: prerequisiti, struttura, configurazione, distribuzione, verifica, troubleshooting essenziale e rimozione dell'ambiente.
- Eventuali file di cloud-init o script di installazione, con nomi in inglese.
- `.gitignore` per escludere state, file `.tfvars` locali e altri file sensibili o generati.

Usa variabili per almeno Resource Group, regione, nome VM, username, SKU, CIDR di accesso, tag comuni e parametri necessari all'immagine. Non codificare credenziali, indirizzi di rete specifici dell'utente o segreti. Spiega che i file di state Terraform possono contenere dati sensibili e devono essere protetti; indica le opzioni per usare un backend remoto sicuro senza inventare una configurazione Azure non richiesta.

## Procedura

Prima di scrivere codice, poni in un unico messaggio le domande necessarie per le decisioni che incidono su sicurezza, accessibilità o compatibilità. Includi almeno:

- la modalità di autenticazione SSH, password oppure chiave pubblica;
- il CIDR autorizzato per SSH;
- chi deve poter raggiungere Tomcat sulla porta 8080;
- regione Azure e accettabilità di una release Ubuntu LTS esplicitamente configurata, se non è possibile determinare in modo affidabile la più recente in modo dinamico.

Non bloccare il lavoro per preferenze non essenziali: se resta una scelta non critica, usa un default sicuro e dichiaralo. Non inventare requisiti, disponibilità regionali, costi, risultati di comandi o compatibilità.

Dopo aver ricevuto le risposte:

1. Controlla la documentazione aggiornata di Terraform e del provider AzureRM per le risorse, i data source, gli argomenti e le versioni utilizzati. Cita i link alle fonti tecniche rilevanti e distingui i fatti verificati dalle assunzioni.
2. Presenta brevemente l'architettura e le decisioni di sicurezza.
3. Fornisci il contenuto completo di ogni file, indicando chiaramente il relativo percorso. Il codice deve essere coerente tra i file e pronto per essere salvato e revisionato.
4. Documenta in italiano l'architettura, le risorse create, i flussi di rete, l'installazione di Java e Tomcat, i parametri da configurare e gli eventuali limiti o costi da verificare.
5. Includi i comandi necessari per autenticarsi ad Azure, inizializzare Terraform, formattare, validare, pianificare, applicare, verificare Tomcat e distruggere le risorse. Evidenzia le operazioni che creano costi e chiedi di controllare il piano prima di applicarlo.
6. Se hai accesso a un ambiente di esecuzione, esegui i controlli appropriati (`terraform fmt -check`, `terraform init` e `terraform validate`) e riferisci i risultati reali. Altrimenti, indica chiaramente che non sono stati eseguiti: non dichiarare il codice testato o validato senza averlo fatto.
7. Concludi con una checklist di sicurezza e di verifica funzionale.

Sii preciso e tecnico. Se una parte della richiesta è ambigua o incompatibile con Azure, Terraform, la release Ubuntu scelta o le altre specifiche, spiega il problema e chiedi chiarimento invece di inventare una soluzione.
