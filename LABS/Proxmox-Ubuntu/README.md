# Terraform: Ubuntu, Nginx, Tomcat e MariaDB su Proxmox VE

Questo progetto crea due VM Ubuntu 26.04 LTS su Proxmox VE:

- **Applicativa**: 2 vCPU, 4 GiB RAM, disco da 20 GB; Java 21, Tomcat 10 e Nginx 1.30 come reverse proxy.
- **Database**: 2 vCPU, 4 GiB RAM, disco da 20 GB; MariaDB 12.3 su una VM dedicata.

Le immagini sono cloud image QCOW2 ufficiali Ubuntu e vengono inizializzate con cloud-init. Il progetto non include backup o disaster recovery.

Alla verifica delle fonti del 5 novembre 2026, la release corrente della serie MariaDB 12.3 era 12.3.3 e quella della serie stabile Nginx 1.30 era 1.30.6. Il provisioning segue le rispettive serie per ricevere gli aggiornamenti di manutenzione; controlla i pacchetti effettivi installati dopo ogni provisioning.

## Prima dell'uso

1. Verifica che il tuo ambiente sia Proxmox VE 9.2 e che il provider/API siano raggiungibili.
2. Copia `terraform.tfvars.example` in `terraform.tfvars` e sostituisci tutti i valori `REPLACE_WITH_*` con i nomi reali del tuo ambiente.
3. Configura per entrambe le VM un nodo, storage disco, storage che accetti contenuto `import`, storage cloud-init, storage che abiliti `snippets`, bridge e rete coerenti. Gli storage devono essere disponibili sul nodo indicato. Proxmox non abilita necessariamente `Import` e `Snippets` per ogni storage.
4. Per DHCP, predisponi prenotazioni DHCP stabili: la regola del firewall DB e il certificato dipendono da indirizzi/nome stabili. Per IPv4 statico imposta CIDR, gateway e DNS appropriati. `database_vm.application_source_cidr` deve identificare la VM applicativa; preferisci `/32` con IP statico o prenotazione DHCP.
5. Elenca in `application_vm.certificate_names` tutti i nomi DNS e/o gli IPv4 con cui i client raggiungono la VM. I nomi sono inseriti come SAN DNS e gli indirizzi IPv4 come SAN IP. Se il client usa un nome/IP non elencato, il certificato non corrisponderà.
6. Assicurati che l'utente SSH di Proxmox possa caricare snippet sul nodo. Terraform usa l'API token per l'API e username/password SSH per trasferire gli snippet. Il provider potrebbe richiedere privilegi aggiuntivi su API e nodo: concedi solo quelli documentati e necessari.
7. Le variabili password sono richieste tramite ambiente. Non inserire segreti in `terraform.tfvars`, Git o nella chat.

Gli esempi in `terraform.tfvars.example` sono segnaposto, non default verificati né configurazioni applicabili. Non eseguire `plan` finché i valori `REPLACE_WITH_*` non sono stati sostituiti.

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

## Installazione e comportamento

- Ubuntu 26.04 usa la stessa immagine cloud su entrambe le VM; Terraform ne controlla il checksum SHA-256 prima del download.
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

`terraform init` scarica il provider. `terraform validate` controlla sintassi e schema dopo l'inizializzazione. `terraform plan` interroga Proxmox e richiede credenziali valide e variabili reali; esamina il piano prima di autorizzare qualsiasi cambiamento.

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

Il download dell'immagine usa un URL della release Ubuntu e un checksum fissato. Per adottare una nuova immagine, aggiorna URL e SHA-256 insieme usando la pubblicazione ufficiale Ubuntu; non rimuovere il controllo del checksum.

### Distruzione (elimina le VM gestite)

```powershell
terraform plan -destroy
terraform destroy
```

Questi comandi possono eliminare le due VM, i dischi, le immagini scaricate e gli snippet cloud-init gestiti da Terraform. Controlla l'elenco completo prima di confermare. Non usarli come test.

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

Il `cloud_init_datastore` è lo storage del disco cloud-init; `snippets_datastore_id` deve supportare gli snippet. Il provider carica questi file tramite SSH sul nodo.

## Risoluzione problemi

- **Storage non supporta `import`/`snippets`**: abilita il tipo di contenuto corretto in Proxmox o scegli uno storage compatibile.
- **Errore di caricamento snippet**: verifica reachability SSH dal client Terraform, autenticazione, permessi di scrittura sul nodo e compatibilità del datastore.
- **Errore di cloud-init o password SSH**: controlla la console Proxmox e i log guest (`/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`). La password guest viene passata tramite i metadati/cloud-init di Proxmox.
- **Versione Nginx diversa da 1.30**: il provisioning fallisce intenzionalmente. Verifica il repository e il supporto della release Ubuntu prima di cambiare vincolo.
- **MariaDB non raggiungibile**: verifica IP/CIDR della VM applicativa e regole UFW. Root è locale per impostazione predefinita; non esporre root via TCP.
- **HTTPS mostra un avviso**: comportamento previsto per un certificato self-signed non distribuito ai client.

## Fonti tecniche consultate

- [Ubuntu 26.04 release cycle](https://ubuntu.com/about/release-cycle)
- [Ubuntu 26.04 cloud image QCOW2 e SHA256SUMS](https://cloud-images.ubuntu.com/releases/resolute/release/)
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
