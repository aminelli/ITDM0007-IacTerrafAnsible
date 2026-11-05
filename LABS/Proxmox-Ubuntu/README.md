# Terraform: Ubuntu, Nginx, Tomcat e MariaDB su Proxmox VE

Questo progetto usa **Packer** per creare un'immagine base QCOW2 partendo dalla cloud image ufficiale Ubuntu 26.04 LTS e **Terraform** per importarla in due VM Proxmox VE:

- **Applicativa**: 2 vCPU, 4 GiB RAM, disco da 20 GB; Java 21, Tomcat 10 e Nginx 1.30 come reverse proxy.
- **Database**: 2 vCPU, 4 GiB RAM, disco da 20 GB; MariaDB 12.3 su una VM dedicata.

Packer avvia la cloud image Ubuntu `.img` (un disco bootabile, non un ISO), verifica il checksum ufficiale, prepara cloud-init e QEMU Guest Agent e produce un file QCOW2 locale. Terraform carica il file su uno storage Proxmox abilitato al contenuto `Import`, lo importa nel disco di ciascuna VM e applica la configurazione cloud-init. Il file `.img` è solo il nome dell'immagine sorgente; l'artefatto prodotto da Packer è in formato QCOW2. Il progetto non include backup o disaster recovery.

Alla verifica delle fonti del 5 novembre 2026, la release corrente della serie MariaDB 12.3 era 12.3.3 e quella della serie stabile Nginx 1.30 era 1.30.6. Il provisioning segue le rispettive serie per ricevere gli aggiornamenti di manutenzione; controlla i pacchetti effettivi installati dopo ogni provisioning.

## Prima dell'uso

1. Verifica che il tuo ambiente sia Proxmox VE 9.2 e che il provider/API siano raggiungibili.
2. Installa Packer e QEMU sul client di build. Packer richiede `qemu-system-x86_64` e `qemu-img` raggiungibili tramite `PATH`; la build usa l'emulazione TCG per non dipendere da un acceleratore specifico.
3. Copia `terraform.tfvars.example` in `terraform.tfvars` e sostituisci tutti i valori `REPLACE_WITH_*` con quelli reali.
4. Per entrambe le VM configura un nodo, uno storage con contenuto `Import`, storage disco, storage cloud-init, storage che abiliti `snippets`, bridge e rete coerenti. Abilita `Import` sullo storage immagini in **Datacenter > Storage**; Proxmox non lo abilita necessariamente per default. Gli storage devono essere disponibili sul nodo indicato.
5. Per DHCP, predisponi prenotazioni DHCP stabili: la regola del firewall DB e il certificato dipendono da indirizzi/nome stabili. Per IPv4 statico imposta CIDR, gateway e DNS appropriati. `database_vm.application_source_cidr` deve identificare la VM applicativa; preferisci `/32` con IP statico o prenotazione DHCP.
6. Elenca in `application_vm.certificate_names` tutti i nomi DNS e/o gli IPv4 con cui i client raggiungono la VM. I nomi sono inseriti come SAN DNS e gli indirizzi IPv4 come SAN IP. Se il client usa un nome/IP non elencato, il certificato non corrisponderà.
7. Assicurati che il client Terraform possa raggiungere l'API Proxmox e, per caricare gli snippet, il nodo tramite SSH. Configura i permessi minimi necessari per entrambe le operazioni.
8. Le variabili password sono richieste tramite ambiente. Non inserire segreti in file versionati, Git o nella chat.

Gli esempi in `terraform.tfvars.example` sono segnaposto, non default verificati né configurazioni applicabili. Non eseguire `plan` o `apply` finché i valori segnaposto non sono stati sostituiti.

## Credenziali e state

In PowerShell, valorizza i segreti prima di eseguire Terraform:

```powershell
$env:TF_VAR_proxmox_api_token = "user@realm!tokenid=secret"
$env:TF_VAR_proxmox_ssh_password = "<password SSH del nodo>"
$env:TF_VAR_application_guest_password = "<password guest applicativa>"
$env:TF_VAR_database_guest_password = "<password guest database>"
```

Il progetto abilita l'autenticazione SSH con password sulle VM, come richiesto, e limita SSH al CIDR `ssh_allowed_cidr`. L'autenticazione password è più esposta a tentativi di accesso rispetto alle chiavi; usa una sorgente amministrativa fidata e password robuste.

Le variabili Terraform `sensitive` riducono la visualizzazione accidentale ma **non** garantiscono che i valori non siano presenti nello state o nei dati cloud-init/Proxmox. Proteggi la directory locale e lo state con permessi appropriati; evita di condividerli o caricarli in sistemi non autorizzati. Non è stato configurato un backend remoto.

Le variabili Packer sono anch'esse marcate `sensitive`. `build_password_hash` è usato da cloud-init nel seed temporaneo e `build_password` serve alla connessione SSH di Packer. Usa una rete di build fidata e non salvare file Packer di variabili o log dettagliati che contengano segreti. Al termine l'account temporaneo nell'immagine viene bloccato, tolto da `sudo`, impostato con shell `nologin` e privato delle chiavi SSH.

## Immagine base con Packer

La configurazione è in `packer/`. Packer QEMU scarica e verifica la cloud image `.img` ufficiale, la avvia con un seed NoCloud temporaneo e produce l'artefatto QCOW2 in `packer/output/ubuntu-2604-base/ubuntu-2604-base`. L'estensione `.img` dell'input non significa ISO: Packer usa `disk_image = true` e imposta esplicitamente `format = "qcow2"`. Terraform carica l'artefatto come file `Import` per ciascun nodo/storage configurato e lo usa per inizializzare il disco della VM. Il percorso dell'artefatto è configurato in `packer_image_path`.

In PowerShell, imposta le variabili richieste (sostituisci i segnaposto e usa lo stesso segreto per la password e il relativo hash):

```powershell
$env:PKR_VAR_build_password = Read-Host "Password temporanea per il build Packer"
$env:PKR_VAR_build_password_hash = $env:PKR_VAR_build_password | openssl passwd -6 -stdin
```

È necessario avere `openssl` installato sul client. Non aggiungere le variabili d'ambiente o il valore della password a file condivisi; chiudi la sessione PowerShell o rimuovi le variabili dopo il build.

Esegui dalla directory `packer\`:

```powershell
packer init .
packer fmt -check .
packer validate .
packer build .
```

`packer build` avvia una VM QEMU locale temporanea e scrive l'immagine QCOW2 nell'output indicato. Il build scarica la cloud image ufficiale e installa QEMU Guest Agent; può richiedere tempo perché usa l'emulazione CPU TCG.

Dopo il build, verifica che il file indicato da `packer_image_path` esista. Packer QEMU produce il file senza estensione; Terraform lo carica su Proxmox con nomi distinti per la VM applicativa e quella database, entrambi con estensione `.qcow2`. Solo allora esegui `terraform init`, `terraform validate` e controlla `terraform plan`.

## Installazione e comportamento

- Ubuntu 26.04 viene preparato da Packer in un file QCOW2 locale; Terraform importa l'immagine e cloud-init applica la configurazione specifica a ciascuna VM.
- L'account guest è creato da cloud-init con username e password forniti tramite variabili.
- La VM applicativa installa OpenJDK 21, Tomcat 10 e Nginx. Il repository ufficiale Nginx è verificato tramite fingerprint GPG; il provisioning fallisce se il pacchetto installato non appartiene alla serie 1.30.
- Nginx ascolta su TCP 80/443, redirige HTTP a HTTPS e inoltra le richieste HTTPS a Tomcat su `127.0.0.1:8080`. Tomcat non termina TLS.
- Nginx crea al primo avvio un certificato self-signed RSA con validità di un anno e SAN coerenti con `application_vm.certificate_names`. Il certificato non è attendibile dai client fino alla distribuzione manuale del certificato/CA e non è adatto a un servizio pubblico senza tale distribuzione. La chiave privata resta sulla VM.
- La VM DB installa la serie MariaDB 12.3 tramite il repository ufficiale, verificando SHA-256 dello script di configurazione. Il repository è impostato sulla serie 12.3, così gli aggiornamenti di manutenzione della serie sono disponibili.
- MariaDB ascolta sulla rete VM, ma il firewall consente TCP 3306 soltanto da `application_source_cidr`. Non viene configurato accesso TCP remoto per root; si conserva il meccanismo locale nativo predefinito di MariaDB. Non viene creato un account applicativo, perché non è stato richiesto.
- Entrambe le VM consentono traffico in uscita e negano in ingresso tutto ciò che non è esplicitamente autorizzato. L'accesso web è consentito soltanto alla VM applicativa.

## Comandi

Esegui tutti i comandi dalla directory che contiene i file `.tf`.

### Verifiche locali (non creano VM)

```powershell
terraform fmt -check
terraform init
terraform validate
terraform plan
```

`terraform init` scarica il provider. `terraform validate` controlla sintassi e schema dopo l'inizializzazione. `terraform plan` interroga Proxmox e richiede un artefatto QCOW2 locale, credenziali valide e variabili reali; esamina il piano prima di autorizzare qualsiasi cambiamento.

### Applicazione (modifica Proxmox)

Solo dopo aver controllato e approvato il piano:

```powershell
terraform apply
```

Terraform chiede conferma prima di applicare il piano. Non usare un piano non esaminato o credenziali non protette.

### Aggiornamento

Verifica prima le release supportate e gli eventuali breaking changes. Aggiorna i vincoli di versione solo deliberatamente, poi esegui:

```powershell
terraform init -upgrade
terraform validate
terraform plan
```

Per aggiornare l'immagine base, aggiorna URL e checksum della cloud image ufficiale in Packer, crea un nuovo QCOW2 e verifica il file prima di eseguire Terraform.

### Distruzione (elimina le VM gestite)

```powershell
terraform plan -destroy
terraform destroy
```

Questi comandi possono eliminare le due VM, i dischi, i file immagine importati e gli snippet cloud-init gestiti da Terraform. Non eliminano l'artefatto QCOW2 locale prodotto da Packer. Controlla l'elenco completo prima di confermare. Non usarli come test.

## Risorse e decisioni da personalizzare

| Valore | Configurazione |
|---|---|
| VM applicativa | 2 vCPU, 4096 MiB, disco importato/espanso a 20 GB |
| VM database | 2 vCPU, 4096 MiB, disco importato/espanso a 20 GB |
| Release OS | Ubuntu 26.04 LTS (Resolute), immagine cloud amd64 |
| Java/Tomcat/Nginx | OpenJDK 21, Tomcat 10 da Ubuntu, Nginx stable 1.30 da nginx.org |
| MariaDB | Community Server serie 12.3 |
| Porte applicative | TCP 80 e 443 |
| Porta database | TCP 3306 consentita solo dal CIDR applicativo configurato |
| SSH | TCP 22 consentita solo dal CIDR amministrativo configurato |

`image_datastore_id` identifica lo storage Proxmox con contenuto `Import`; `cloud_init_datastore` è lo storage del disco cloud-init e `snippets_datastore_id` deve supportare gli snippet. Il provider carica i file QCOW2 tramite API e gli snippet tramite SSH.

## Risoluzione problemi

- **Storage non supporta `import`/`snippets`**: abilita il tipo di contenuto corretto in Proxmox o scegli uno storage compatibile.
- **Packer non avvia la build**: verifica che `qemu-system-x86_64` e `qemu-img` siano nel `PATH` e che la connessione internet consenta di scaricare l'immagine cloud.
- **Errore di importazione QCOW2**: verifica che il file indicato da `packer_image_path` esista e che lo storage Proxmox del nodo abbia abilitato il contenuto `Import`.
- **Errore di caricamento snippet**: verifica reachability SSH dal client Terraform, autenticazione, permessi di scrittura sul nodo e compatibilità del datastore.
- **Errore di cloud-init o password SSH**: controlla la console Proxmox e i log guest (`/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`). La password guest viene passata tramite i metadati/cloud-init di Proxmox.
- **Versione Nginx diversa da 1.30**: il provisioning fallisce intenzionalmente. Verifica il repository e il supporto della release Ubuntu prima di cambiare vincolo.
- **MariaDB non raggiungibile**: verifica IP/CIDR della VM applicativa e regole UFW. Root è locale per impostazione predefinita; non esporre root via TCP.
- **HTTPS mostra un avviso**: comportamento previsto per un certificato self-signed non distribuito ai client.

## Fonti tecniche consultate

- [Ubuntu 26.04 release cycle](https://ubuntu.com/about/release-cycle)
- [Ubuntu 26.04 cloud image e SHA256SUMS](https://cloud-images.ubuntu.com/releases/resolute/release/)
- [Pacchetto OpenJDK 21 su Ubuntu 26.04](https://packages.ubuntu.com/resolute/openjdk-21-jre-headless)
- [Pacchetto Tomcat 10 su Ubuntu 26.04](https://packages.ubuntu.com/resolute/tomcat10)
- [Pacchetto OpenJDK 21 su Ubuntu 26.04](https://packages.ubuntu.com/resolute/openjdk-21-jre-headless)
- [Pacchetto Tomcat 10 su Ubuntu 26.04](https://packages.ubuntu.com/resolute/tomcat10)
- [Terraform 1.17.1 release](https://github.com/hashicorp/terraform/releases/tag/v1.17.1)
- [Proxmox VE 9.2 announcement](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-virtual-environment-9-2)
- [bpg/proxmox 0.120.0 release](https://github.com/bpg/terraform-provider-proxmox/releases/tag/v0.120.0)
- [Documentazione risorsa VM bpg/proxmox 0.120.0](https://github.com/bpg/terraform-provider-proxmox/blob/v0.120.0/docs/resources/virtual_environment_vm.md)
- [Documentazione snippet bpg/proxmox 0.120.0](https://github.com/bpg/terraform-provider-proxmox/blob/v0.120.0/docs/resources/virtual_environment_file.md)
- [Documentazione download file bpg/proxmox 0.120.0](https://github.com/bpg/terraform-provider-proxmox/blob/v0.120.0/docs/resources/download_file.md)
- [MariaDB 12.3 release notes e stato LTS](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements)
- [MariaDB repository setup, opzioni e checksum](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/mariadb-package-repository-setup-and-usage)
- [Autenticazione nativa MariaDB root@localhost](https://mariadb.com/docs/server/security/user-account-management/authentication-from-mariadb-10-4)
- [Autenticazione nativa MariaDB root@localhost](https://mariadb.com/docs/server/security/user-account-management/authentication-from-mariadb-10-4)
- [Nginx 1.30 changelog](https://nginx.org/en/CHANGES-1.30)
- [Nginx repository e distribuzioni supportate](https://nginx.org/en/linux_packages.html)
- [Packer 1.16.2 release](https://releases.hashicorp.com/packer/1.16.2/)
- [Packer QEMU plugin 1.1.8](https://github.com/hashicorp/packer-plugin-qemu/releases/tag/v1.1.8)
- [Documentazione builder Packer QEMU](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu)
