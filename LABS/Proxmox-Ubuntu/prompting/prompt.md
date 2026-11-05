# Progetto Terraform: Ubuntu, Nginx, Tomcat e MariaDB su Proxmox

Agisci come un/una senior engineer specializzato/a in IaC, DevOps, Terraform/HCL, Proxmox VE, QEMU/KVM, cloud-init e automazione Linux.

## Obiettivo

Esamina il workspace e realizza un progetto Terraform manutenibile per effettuare il provisioning su Proxmox VE di due macchine virtuali Ubuntu basate su immagini cloud QCOW2 con supporto cloud-init. Entrambe devono usare la stessa versione di Ubuntu, ossia l'ultima release LTS disponibile e verificata al momento del lavoro.

1. **VM applicativa**: 2 vCPU, 4 GiB di RAM e disco di sistema da 20 GB; Java 21; Apache Tomcat 10; Nginx come reverse proxy; firewall host configurato per consentire HTTP/HTTPS sulle porte TCP 80 e 443.
2. **VM database**: 2 vCPU, 4 GiB di RAM e disco di sistema da 20 GB; MariaDB.

## Tecnologie e versioni richieste

- Terraform 1.17.1.
- Proxmox VE 9.2.
- Provider Terraform `bpg/proxmox` 0.120.0 (indicato come latest dall'utente).
- MariaDB 12.3.
- Nginx 1.30.

Verifica l'esistenza, la disponibilità, lo stato di supporto e la compatibilità delle versioni richieste tramite fonti ufficiali. In particolare, non assumere che MariaDB 12.3 sia una release LTS o che il provider 0.120.0 sia ancora latest: dichiara ciò che risulta dalle fonti consultate. Se una versione richiesta non esiste, non è supportata o non è compatibile, non sostituirla autonomamente: spiega il problema e chiedi conferma prima di scegliere una versione alternativa. Blocca le versioni confermate nella configurazione e documenta come aggiornarle.

## Configurazione richiesta

- Rendi parametrizzabili nei manifest Terraform il nodo, lo storage, il bridge e la configurazione di rete (DHCP o IP statico) per entrambe le VM. Proponi default sensati e modificabili, ma non presentare valori d'ambiente come verificati senza evidenza.
- Le due VM devono usare la stessa release Ubuntu e immagini cloud ufficiali compatibili con Proxmox, QCOW2 e cloud-init.
- Per l'accesso amministrativo alle VM usa username e password forniti tramite variabili Terraform, non certificati SSH. Distingui le credenziali Proxmox da quelle degli account guest e fornisci un metodo sicuro di inserimento dei segreti. Non includere password reali, hash o altri segreti nei file versionati, esempi, output o documentazione.
- Sulla VM applicativa configura Tomcat 10 con Java 21. Tomcat non deve terminare direttamente TLS: usa Nginx come reverse proxy, con certificato HTTPS self-signed generato per Nginx. Nginx deve gestire le connessioni pubbliche TCP sulle porte 80 e 443 e inoltrare le richieste a Tomcat su una porta interna non in conflitto.
- Documenta creazione e installazione del certificato self-signed, nomi/IP inclusi, rinnovo e avvisi di trust per i client. Non presentarlo come certificato adatto a un servizio pubblico senza distribuzione della relativa CA.
- Installa MariaDB 12.3 sulla VM dedicata. L'utente richiede l'accesso integrato nativo di MariaDB tramite account root, le porte classiche e nessun certificato. Verifica e descrivi il comportamento effettivo dell'autenticazione root per la versione scelta; non inventare password o modalità di autenticazione.
- Configura la porta standard MariaDB (TCP 3306) e le altre porte strettamente necessarie ai servizi richiesti. Non esporre MariaDB a Internet o all'intera rete: limita bind, firewall e sorgenti autorizzate al minimo necessario. Chiedi conferma se l'accesso root remoto o l'ambito di accesso al database non sono chiari; spiega i rischi e proponi l'accesso locale o limitato alla sola VM applicativa, senza abilitare l'accesso remoto indiscriminato.
- Non prevedere piani o procedure di backup e disaster recovery: l'utente li ha esplicitamente esclusi. Puoi segnalare in modo conciso le implicazioni, ma non aggiungere implementazioni o attività di backup/DR al progetto.

## Prima di implementare

1. Esamina i file presenti, le convenzioni e le modifiche già esistenti. Riutilizza ciò che è adatto e non sovrascrivere o rimuovere modifiche non pertinenti.
2. Verifica versioni, immagini QCOW2, supporto cloud-init, risorse e attributi del provider e procedure d'installazione usando fonti ufficiali. Cita le fonti effettivamente consultate e distingui fatti verificati, assunzioni e raccomandazioni.
3. Prima di scegliere aspetti che incidono su sicurezza, connettività o costi, chiedi in modo raggruppato soltanto i dati mancanti indispensabili. In particolare, chiarisci:
   - valori effettivi di nodo, storage e bridge Proxmox, e configurazione di rete (DHCP o parametri IP statici, gateway e DNS);
   - hostname o nomi DNS/IP da includere nel certificato self-signed e comportamento desiderato per le richieste HTTP (ad esempio reindirizzamento a HTTPS);
   - account guest e modalità sicura di fornitura delle password, separatamente dalle credenziali del provider Proxmox;
   - se MariaDB deve accettare connessioni dalla VM applicativa e quale sorgente autorizzare sulla porta 3306, dato che è richiesto l'uso dell'account root.
4. Attendi le risposte prima di procedere con scelte architetturali che incidono su sicurezza o raggiungibilità. Non bloccare il lavoro per preferenze non essenziali: proponi opzioni o default provvisori chiaramente documentati.

## Requisiti di implementazione

- Usa inglese per nomi di file, variabili, risorse, identificatori e commenti negli script e nei manifest; redigi la documentazione in italiano.
- Per ciascuna VM usa l'immagine cloud ufficiale della stessa release Ubuntu. Documenta release, fonte, modalità di verifica dell'integrità e aggiornamento; non inventare URL o checksum.
- Verifica compatibilità e supporto di Java 21, Tomcat 10 (preferibilmente 10.1 se supportato), Nginx 1.30 e MariaDB 12.3 con la release Ubuntu scelta. Se i repository ufficiali della release non forniscono esattamente le versioni richieste, non cambiare versione in silenzio: spiega le alternative e chiedi conferma.
- Usa configurazione Terraform parametrizzabile con tipi, descrizioni e validazioni appropriate. Fornisci esempi senza credenziali reali. Blocca le versioni di Terraform/provider in modo esplicito.
- Prediligi provisioning ripetibile e idempotente e configura i servizi per l'avvio automatico. Applica il principio del privilegio minimo e limita ogni firewall al traffico effettivamente necessario; consenti SSH solo secondo la configurazione concordata.
- Marca le variabili sensibili, ma spiega che `sensitive` limita la visualizzazione e non rimuove i valori dallo state Terraform. Indica come proteggere lo state e non salvare segreti in cloud-init o user-data in chiaro nel repository.
- Non eseguire `terraform apply`, non modificare risorse Proxmox reali e non eseguire `terraform destroy` senza autorizzazione esplicita. Non usare mai `destroy` come verifica.

## Documentazione richiesta

Genera documentazione Markdown dettagliata e approfondita in italiano, che copra:

- architettura delle due VM, flussi di rete e dipendenze fra provisioning e configurazione;
- risorse Terraform create, dimensioni, dischi, rete e cloud-init;
- prerequisiti e configurazioni richieste su Proxmox;
- file del progetto, variabili, default, valori da personalizzare e modalità sicura di fornire credenziali;
- installazione e configurazione di Ubuntu, Java, Tomcat, Nginx, certificato self-signed, MariaDB e firewall;
- porte pubbliche e interne, proxy, accesso MariaDB e limiti di sicurezza, compresi account root e certificato self-signed;
- comandi per formattare, inizializzare, validare, pianificare, applicare, aggiornare e distruggere le risorse;
- prerequisiti, directory di esecuzione e impatto di ciascun comando, distinguendo chiaramente operazioni di sola lettura da quelle che modificano o eliminano risorse;
- gestione e protezione dello state Terraform, senza introdurre piani o procedure di backup/disaster recovery;
- assunzioni, limiti e decisioni da confermare.

## Verifica e consegna

- Verifica le risorse e gli attributi Terraform con la documentazione ufficiale del provider alla versione confermata.
- Esegui le verifiche locali non distruttive disponibili, ad esempio `terraform fmt -check` e `terraform validate`. Se mancano strumenti, dipendenze o credenziali, dichiara precisamente cosa non è stato possibile verificare; non dichiarare superata una verifica non eseguita.
- Controlla esplicitamente: stessa release Ubuntu su entrambe le VM; 2 vCPU, 4 GiB RAM e disco da 20 GB ciascuna; Java 21 e Tomcat 10 sulla VM applicativa; Nginx e porte pubbliche TCP 80/443; MariaDB 12.3 sulla VM dedicata e configurazione coerente della porta TCP 3306.
- Al termine, riepiloga i file creati o modificati, le scelte effettuate, i controlli eseguiti e gli eventuali passaggi ancora richiesti all'utente. Cita le fonti ufficiali realmente consultate e segnala eventuali versioni richieste non verificabili o incompatibili.
