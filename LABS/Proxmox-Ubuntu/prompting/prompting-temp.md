# Contesto

Il contesto tecnologico è IaC, DevOps, Toolchains DevOps, Terraform + HCL, Cloud-init, Proxmox, Qemu + KVM.

# Obiettivi:

Voglio realizzare un progetto Terraform che mi consenta di deployare in un ambiente proxmox una macchina virtuale con i seguenti requisiti:

- OS Ubuntu ultima versione LTS
- L'immagine da utilizzare deve essere di tipo "qcow" con supporto cloud-init
- Il deploy deve essere effettuato su proxmox
- Risorse VM Ubuntu:
  - vCPU = 2
  - RAM = 4Gb
  - Storage = 20Gb
- Nell'OS devono essere installati:
  - Tomact 10 configurato su porta 80 e 443
  - JVM 21
  - Aperture firewall 80 e 443
- Una seconda macchina virtuale con MariaDB ultima versione LTS
- Risorse VM con MariaDB:
  - vCPU = 2
  - RAM = 4Gb
  - Storage = 20Gb


# Tecnologie:

- Terraform v1.17.1
- ProxMox 9.2
- Provider terraform "bpg/proxmox" versione 0.120.0 (latest)
- MariaDB 12.3
- nginx 1.30

# Configurazioni Ambienti:

- Per il nodo, storage e bridge di rete Proxmox, oltre ai parametri di rete della VM (DHCP o indirizzamento statico) prevedi parte parametrica nei manifest terraform con default preimpostati in funzione della tua esperienza. Ciò sia per la VM con ubuntu sia con la VM con MariaDB. Per le due macchine virtuali utilizza sempre la stessa versione Linux.
- Per la modalità sicura di autenticazione e accesso SSH non prevedere certificati ma username e password da specificare tramite variabili terraform (per entrambe le VM).
- Per Tomcat:
  - genera un certificato HTTPS self-signed. 
  - Tomcat non termina direttamente TLS per cui devi prevedere un reverse proxy nginx;
- Per MariaDB:
  - deve risiedere su VM dedicata e separata
  - abilita solo l'accesso built-in tramite utenza root e configura/apri le porte classiche.
  - Non prevedere l'uso di certificati
  - Non prevedere piani di backup o disaster recovery


# Altre informazioni

Negli script e manifest usa una nomenclatura in inglese.

Genera una documentazione dettagliata e approfondita in markdown e in italiano contenente:

  - Descrizione dell'architettura
  - descrizione delle risorse di cui si effettua il provisioning
  - elenco e di tutti i comandi utili per creare, configurare, distruggere etc. l'ambiente.
  - tutto ciò che è di interesse e utile ai fini della documentazione stessa

Sii preciso, tecnico, e non inventare nulla.

Se hai bisogno di altro per aspetti che non sono riuscito a desrivere o che ho descritto male, ponimi le domande necessarie prima di iniziare a generare il tutto.


